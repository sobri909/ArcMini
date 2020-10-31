//
//  TimelineRangeSummary.swift
//  Arc
//
//  Created by Matt Greenfield on 13/3/19.
//  Copyright © 2019 Big Paua. All rights reserved.
//

import GRDB
import Photos
import Sentry
import LocoKit
import SwiftNotes

class TimelineRangeSummary: TimelineObject, Backupable, Hashable {

    let summaryId: UUID
    let dateRange: DateInterval
    let segment: TimelineSegment

    var isFavourite: Bool = false { didSet { if oldValue != isFavourite { hasChanges = true } } }
    var itemsNeedingConfirmCount: Int = 0 { didSet { hasChanges = true } }
    
    private var _invalidated = false
    public var invalidated: Bool { return _invalidated }
    public func invalidate() { _invalidated = true }

    var observers: [Any] = []

    // MARK: -

    init?(segment: TimelineSegment) {
        self.summaryId = UUID()
        self.segment = segment
        
        guard let dateRange = segment.dateRange else { return nil }
        self.dateRange = dateRange

        addObservers()
        RecordingManager.store.add(self)
    }

    init(from dict: [String: Any?]) {
        if let uuidString = dict["summaryId"] as? String {
            self.summaryId = UUID(uuidString: uuidString)!
        } else {
            self.summaryId = UUID()
        }
        self.lastSaved = dict["lastSaved"] as? Date
        var initDateRange: DateInterval
        if let startDate = dict["startDate"] as? Date, let endDate = dict["endDate"] as? Date {
            initDateRange = DateInterval(start: startDate, end: endDate)
            self.dateRange = initDateRange
        } else {
            fatalError("Invalid dateRange")
        }

        self.segment = RecordingManager.store.segment(for: dateRange)
        
        if LocomotionManager.highlander.applicationState != .active {
            self.segment.stopUpdating()
        }

        self.isFavourite = dict["isFavourite"] as? Bool ?? false
        if let count = dict["itemsNeedingConfirmCount"] as? Int64 { self.itemsNeedingConfirmCount = Int(count) }
        
        // Backupable
        self.backupLastSaved = dict["backupLastSaved"] as? Date

        addObservers()
        RecordingManager.store.add(self)
    }

    func addObservers() {
        let updateObserver = when(segment, does: .timelineSegmentUpdated) { [weak self] _ in
            onMain { self?.segmentUpdated() }
        }
        observers.append(updateObserver)

        let activeObserver = when(UIApplication.didBecomeActiveNotification) { [weak self] _ in
            self?.segment.startUpdating()
        }
        observers.append(activeObserver)

        let backgroundObserver = when(UIApplication.didEnterBackgroundNotification) { [weak self] _ in
            self?.segment.stopUpdating()
        }
        observers.append(backgroundObserver)
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    // MARK: -

    func segmentUpdated() {
        _summaries = nil
        _photoAssetsCount = nil
        _photoAssetsInside = nil
        dedupedTask(scope: self, after: 10) { [weak self] in
            self?.updateNeedsConfirmCount()
        }
    }

    // MARK: -

    var _summaries: [TimelineObjectSummary]?
    var summaries: [TimelineObjectSummary] {
        if let cached = _summaries { return cached }
        _summaries = collateSummaries()
        return _summaries!

    }
    var placeSummaries: [PlaceSummary] { return summaries.compactMap { $0 as? PlaceSummary } }
    var activitySummaries: [ActivitySummary] { return summaries.compactMap { $0 as? ActivitySummary } }

    var _photoAssetsCount: Int?
    var photoAssetsCount: Int {
        if let cached = _photoAssetsCount { return cached }
        var count = 0
        for case let item as ArcTimelineItem in segment.timelineItems {
            if let itemCount = item.photos?.count {
                count += itemCount
            }
        }
        _photoAssetsCount = count
        return count
    }

    var photoAssets: PHFetchResult<PHAsset> {
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "creationDate >= %@ AND creationDate <= %@",
                                        dateRange.start as NSDate, dateRange.end as NSDate)
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.wantsIncrementalChangeDetails = false
        return PHAsset.fetchAssets(with: options)
    }

    var _photoAssetsInside: [PHAsset]?
    var photoAssetsInside: [PHAsset] {
        if let cached = _photoAssetsInside { return cached }
        var assets: [PHAsset] = []
        photoAssets.enumerateObjects { asset, index, stop in
            for case let item as ArcTimelineItem in self.segment.timelineItems {
                if asset.hasLocationInside(timelineItem: item) {
                    assets.append(asset)
                    break
                }
            }
        }
        _photoAssetsInside = assets
        return assets
    }

    // MARK: -

    func collateSummaries() -> [TimelineObjectSummary] {
        guard let dateRange = segment.dateRange else { return [] }

        var freshSummaries: [TimelineObjectSummary] = []

        for case let item as ArcTimelineItem in segment.timelineItems {
            if item.isDataGap { continue }

            var summary: TimelineObjectSummary?

            if let visit = item as? ArcVisit, let place = visit.place {
                if let existing = freshSummaries.first(where: { ($0 as? PlaceSummary)?.place == place }) {
                    summary = existing
                } else {
                    summary = PlaceSummary(place: place, dateRange: dateRange)
                    freshSummaries.append(summary!)
                }
            }

            if let path = item as? ArcPath, let activityType = path.modeMovingActivityType {
                if let existing = freshSummaries.first(where: { ($0 as? ActivitySummary)?.activityType == activityType }) {
                    summary = existing
                } else {
                    summary = ActivitySummary(activityType: activityType, dateRange: dateRange)
                    freshSummaries.append(summary!)
                }
            }

            summary?.add(item)
        }

        return freshSummaries.sorted { $0.duration > $1.duration }
    }
    
    func updateNeedsConfirmCount() {
        // don't waste energy doing this if none of the items are newer
        if let lastSaved = lastSaved, let itemsLastSaved = segment.timelineItems.compactMap({ $0.lastSaved }).max() {
            guard itemsLastSaved > lastSaved else { return }
        }

        Jobs.addSecondaryJob("TimelineRangeSummary.updateNeedsConfirmCount.\(dateRange.middle.dayLogString)", dontDupe: true) { [weak self] in
            guard let self = self else { return }
            self.itemsNeedingConfirmCount = self.segment.itemsNeedingConfirm.count
            self.save()
        }
    }

    // MARK: - TimelineObject

    var objectId: UUID { return summaryId }
    var source: String = "ArcApp"
    var store: TimelineStore? { return RecordingManager.store }
    var transactionDate: Date?
    var lastSaved: Date?
    var hasChanges: Bool = false

    func save(immediate: Bool = true) {
        do {
            try (store as? ArcStore)?.arcPool.write { db in
                self.transactionDate = Date()
                try self.save(in: db)
                self.lastSaved = self.transactionDate
            }
        } catch {
            logger.error("\(error)")
        }
    }

    // MARK: - PersistableRecord
    
    public static let databaseTableName = "TimelineRangeSummary"

    func encode(to container: inout PersistenceContainer) {
        container["summaryId"] = summaryId.uuidString
        container["source"] = source
        container["lastSaved"] = transactionDate ?? lastSaved ?? Date()
        container["startDate"] = dateRange.start
        container["endDate"] = dateRange.end
        container["isFavourite"] = isFavourite
        container["itemsNeedingConfirmCount"] = itemsNeedingConfirmCount
        
        // Backupable
        container["backupLastSaved"] = backupLastSaved
    }
    
    // MARK: - Backupable
    
    var backupLastSaved: Date? { didSet { if oldValue != backupLastSaved { saveNoDate() } } }
    static var backupFolderPrefixLength = 1
    
    func saveNoDate() {
        hasChanges = true
        do {
            try (store as? ArcStore)?.arcPool.write { db in
                try self.save(in: db)
            }
        } catch {
            logger.error("\(error)")
        }
    }
    
    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case summaryId
        case source
        case dateRange
        case isFavourite
        case itemsNeedingConfirmCount
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.summaryId = (try? container.decode(UUID.self, forKey: .summaryId)) ?? UUID()
        self.dateRange = try container.decode(DateInterval.self, forKey: .dateRange)
        if let source = try? container.decode(String.self, forKey: .source) { self.source = source }
        self.isFavourite = (try? container.decode(Bool.self, forKey: .isFavourite)) ?? false
        self.itemsNeedingConfirmCount = (try? container.decode(Int.self, forKey: .itemsNeedingConfirmCount)) ?? 0

        self.segment = RecordingManager.store.segment(for: dateRange)
        addObservers()
        RecordingManager.store.add(self)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(summaryId, forKey: .summaryId)
        try container.encode(source, forKey: .source)
        try container.encode(dateRange, forKey: .dateRange)
        try container.encode(isFavourite, forKey: .isFavourite)
        try container.encode(itemsNeedingConfirmCount, forKey: .itemsNeedingConfirmCount)
    }

    // MARK: - Hashable

    func hash(into hasher: inout Hasher) {
        hasher.combine(summaryId)
    }

    // MARK: - Equatable

    static func == (lhs: TimelineRangeSummary, rhs: TimelineRangeSummary) -> Bool {
        return lhs.summaryId == rhs.summaryId
    }

    // MARK: - Summary classes

    class PlaceSummary: TimelineObjectSummary {
        var dateRange: DateInterval
        var place: Place
        var duration: TimeInterval = 0

        init(place: Place, dateRange: DateInterval) {
            self.dateRange = dateRange
            self.place = place
        }

        func add(_ item: ArcTimelineItem) {
            if let visit = item as? ArcVisit {
                add(visit: visit)
            }
        }

        func add(visit: ArcVisit) {
            guard visit.place == place else { return }
            guard let overlap = visit.dateRange?.intersection(with: dateRange) else { return }
            duration += overlap.duration
        }
    }

    class ActivitySummary: TimelineObjectSummary {
        var dateRange: DateInterval
        var activityType: ActivityTypeName
        var duration: TimeInterval = 0
        var distance: CLLocationDistance = 0

        init(activityType: ActivityTypeName, dateRange: DateInterval) {
            self.dateRange = dateRange
            self.activityType = activityType
        }

        func add(_ item: ArcTimelineItem) {
            if let path = item as? ArcPath {
                add(path: path)
            }
        }

        func add(path: ArcPath) {
            guard path.modeMovingActivityType == activityType else { return }
            guard let overlap = path.dateRange?.intersection(with: dateRange) else { return }

            duration += overlap.duration

            if overlap == path.dateRange {
                distance += path.distance
                
            } else {
                let samples = path.samples.filter { overlap.contains($0.date) }
                distance += samples.distance
            }
        }
    }

}

// MARK: -

protocol TimelineObjectSummary {
    var dateRange: DateInterval { get }
    var duration: TimeInterval { get }
    func add(_ item: ArcTimelineItem)
}
