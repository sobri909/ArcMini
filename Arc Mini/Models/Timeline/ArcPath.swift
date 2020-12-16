//
//  ArcPath.swift
//  LearnerCoacher
//
//  Created by Matt Greenfield on 13/12/17.
//  Copyright © 2017 Big Paua. All rights reserved.
//

import GRDB
import LocoKit
import SwiftNotes
import CoreLocation

class ArcPath: Path, ArcTimelineItem {

    static let minimumActivityTypeConfidenceScore: Double = 2.0
    static let minimumAltitudeChangeForGraphShowing: Double = 30
    static let minimumNormalisedScoreForActivityTypeCertain: Double = 0.5
    static let minimumNormalisedScoreForActivityTypeKnown: Double = 0.2

    // MARK: - Init

    public required init(in store: TimelineStore) { super.init(in: store) }

    public required init(from dict: [String: Any?], in store: TimelineStore) {

        // ArcPath
        self._manualActivityType = dict["manualActivityType"] as? Bool ?? false
        self._uncertainActivityType = dict["uncertainActivityType"] as? Bool ?? true
        self._unknownActivityType = dict["unknownActivityType"] as? Bool ?? true
        self.activityTypeConfidenceScore = dict["activityTypeConfidenceScore"] as? Double ?? 0

        // ArcTimelineItem
        self.activeEnergyBurned = dict["activeEnergyBurned"] as? Double
        self.averageHeartRate = dict["averageHeartRate"] as? Double
        self.maxHeartRate = dict["maxHeartRate"] as? Double
        if let steps = dict["hkStepCount"] as? Double {
            self.hkStepCount = Int(steps)
        }
        
        // Backupable
        self.backupLastSaved = dict["backupLastSaved"] as? Date

        super.init(from: dict, in: store)
    }

    // MARK: - Activity type

    var _manualActivityType: Bool? { didSet { if oldValue != _manualActivityType { hasChanges = true } } }
    var manualActivityType: Bool {
        if let cached = _manualActivityType { return cached }
        updateManualActivityTypeValue()
        return _manualActivityType ?? false
    }

    var _needsUserCleanup: Bool? // mild
    var _uncertainActivityType: Bool? { didSet { if oldValue != _uncertainActivityType { hasChanges = true } } } // moderate
    var _unknownActivityType: Bool? { didSet { if oldValue != _unknownActivityType { hasChanges = true } } } // severe
    var needsUserCleanup: Bool {
        if let cached = _needsUserCleanup { return cached }
        updateActivityTypeConfidence()
        return _needsUserCleanup ?? false
    }
    var uncertainActivityType: Bool {
        if let cached = _uncertainActivityType { return cached }
        updateActivityTypeConfidence()
        return _uncertainActivityType ?? true
    }
    var unknownActivityType: Bool {
        if let cached = _unknownActivityType { return cached }
        updateActivityTypeConfidence()
        return _unknownActivityType ?? true
    }

    var activityTypeConfidenceScore: Double = 0 { didSet { if oldValue != activityTypeConfidenceScore { hasChanges = true } } }

    var workoutRouteId: UUID? { didSet { hasChanges = true } }

    func updateManualActivityTypeValue() {
        let previousValue = _manualActivityType

        let confirmedCount = samples.lazy.filter { $0.confirmedType != nil }.count

        if Double(confirmedCount) / Double(samples.count) > 0.5 {
            _manualActivityType = true
        } else {
            _manualActivityType = false
        }

        if _manualActivityType != previousValue { save() }

        if _manualActivityType == true { UserActivityTypesCache.highlander.updateModelsContaining(self) }
    }

    func updateActivityTypeConfidence() {
        Jobs.addSecondaryJob("updateActivityTypeConfidence.\(itemId.shortString)", dontDupe: true) { [weak self] in
            guard let self = self else { return }
            guard RecordingManager.recorder.canClassify() else { return }

            // if uncertain/unknown, then there's user cleanup required (but the inverse isn't always true)
            defer {
                if self._uncertainActivityType == true || self._unknownActivityType == true { self._needsUserCleanup = true }
                self.save()
            }

            // assume false until something proves otherwise
            self._unknownActivityType = false
            self._uncertainActivityType = false
            self._needsUserCleanup = false

            // no mode moving type? no confidence
            guard let activityType = self.modeMovingActivityType else {
                self._uncertainActivityType = true
                self._unknownActivityType = true
                return
            }

            // "unknown" paths are always uncertain
            if activityType == .unknown {
                self._uncertainActivityType = true
                self._unknownActivityType = true
                return
            }

            // checks below here are only for auto types
            if self.manualActivityType {
                self._uncertainActivityType = false
                self._unknownActivityType = false
                return
            }

            guard let results = self.classifierResults else {
                self._uncertainActivityType = true
                self._unknownActivityType = true
                return
            }

            guard let typeResult = results[activityType] else {
                self._uncertainActivityType = true
                self._unknownActivityType = true
                return
            }

            // item's type score is too low?
            let normalisedScore = typeResult.normalisedScore(in: results)
            if normalisedScore < ArcPath.minimumNormalisedScoreForActivityTypeCertain {
                self._uncertainActivityType = true
                if normalisedScore < ArcPath.minimumNormalisedScoreForActivityTypeKnown {
                    self._unknownActivityType = true
                }
                return
            }

            self.updateActivityTypeConfidenceScore()

            // type confidence is too low?
            if self.activityTypeConfidenceScore < ArcPath.minimumActivityTypeConfidenceScore {
                self._uncertainActivityType = true
                return
            }
        }
    }

    // ratio of chosen type vs next best match (or best match, if chosen isn't the highest scorer)
    func updateActivityTypeConfidenceScore() {
        guard let activityType = modeMovingActivityType else { return }

        guard let results = classifierResults else {
            activityTypeConfidenceScore = 0
            return
        }

        guard let currentTypeScore = results[activityType]?.score else {
            activityTypeConfidenceScore = 0
            return
        }

        guard let nextTypeScore = results.first(where: { $0.name != activityType })?.score else {
            activityTypeConfidenceScore = 100
            return
        }

        if nextTypeScore < currentTypeScore {
            activityTypeConfidenceScore = (currentTypeScore / nextTypeScore).clamped(min: 0, max: 100)
        } else {
            activityTypeConfidenceScore = 0
        }
    }

    func trainActivityType(to confirmedType: ActivityTypeName) {
        let previousType = movingActivityType

        for sample in samples {
            // let confident stationary samples survive
            if sample.hasUsableCoordinate, sample.activityType == .stationary,
                let typeScore = sample.classifierResults?[.stationary]?.score, typeScore > 0.1
            { continue }

            // let manual bogus samples survive
            if sample.confirmedType == .bogus { continue }

            sample.confirmedType = confirmedType
        }

        // if we're forcing it to stationary, brexit all the stationary segments
        if confirmedType == .stationary {
            for segment in segments where segment.activityType == .stationary {
                self.brexit(segment, place: nil)
            }
            return
        }

        samplesChanged()

        // update the ML model
        UserActivityTypesCache.highlander.updateModelsContaining(self, activityType: confirmedType)

        // previous type model might need an update too
        if confirmedType != previousType {
            UserActivityTypesCache.highlander.updateModelsContaining(self, activityType: previousType)
        }

        trigger(.updatedTimelineItem, on: self)

        // need to reprocess after the change
        TimelineProcessor.process(from: self)
    }

    // MARK: - Health

    var activeEnergyBurned: Double? { didSet { hasChanges = true } }
    var averageHeartRate: Double? { didSet { hasChanges = true } }
    var maxHeartRate: Double? { didSet { hasChanges = true } }
    var hkStepCount: Int? { didSet { hasChanges = true } }
    var lastHealthKitLookup: Date?

    var _trackPlays: [TrackPlay]?
    
    // MARK: - UI
    
    var _speedGraphData: [[(TimeInterval, CLLocationSpeed)]]?
    var speedGraphData: [[(TimeInterval, CLLocationSpeed)]] {
        if let cached = _speedGraphData { return cached }
        var groups: [[(TimeInterval, CLLocationSpeed)]] = []
        var currentGroup: [(TimeInterval, CLLocationSpeed)] = []
        for sample in samples {
            guard sample.hasUsableCoordinate, let location = sample.location, location.horizontalAccuracy < 100, location.speed >= 0 else {
                if !currentGroup.isEmpty {
                    groups.append(currentGroup)
                    currentGroup = []
                }
                continue
            }
            currentGroup.append((sample.date.timeIntervalSince1970, location.speed))
        }
        if !currentGroup.isEmpty {
            groups.append(currentGroup)
        }
        _speedGraphData = groups
        return groups
    }
    
    // MARK: - ArcTimelineItem
    
    var needsConfirm: Bool {
        if isDataGap { return false }
        if modeMovingActivityType == nil { return true }
        if unknownActivityType { return true }
        if uncertainActivityType { return true }
        if needsUserCleanup { return true }
        return false
    }

    // MARK: - TimelineItem

    override func sampleTypesChanged() {
        super.sampleTypesChanged()
        _manualActivityType = nil
        _needsUserCleanup = nil
        _uncertainActivityType = nil
        _unknownActivityType = nil
        _speedGraphData = nil
    }
    override func scoreForConsuming(item: TimelineItem) -> ConsumptionScore {

        // a manual place can't be consumed
        if let visit = item as? ArcVisit, visit.manualPlace { return .impossible }

        return super.scoreForConsuming(item: item)
    }

    // MARK: - Backupable
    
    static var backupFolderPrefixLength = 2
    var backupLastSaved: Date? { didSet { if oldValue != backupLastSaved { saveNoDate() } } }

    public func saveNoDate() {
        hasChanges = true
        arcStore?.saveNoDate(self)
    }

    // MARK: - Persistable

    override func encode(to container: inout PersistenceContainer) {
        super.encode(to: &container)

        // ArcItem
        container["activeEnergyBurned"] = activeEnergyBurned
        container["averageHeartRate"] = averageHeartRate
        container["maxHeartRate"] = maxHeartRate
        container["hkStepCount"] = hkStepCount

        // ArcPath
        container["manualActivityType"] = _manualActivityType ?? false
        container["uncertainActivityType"] = _uncertainActivityType ?? true
        container["unknownActivityType"] = _unknownActivityType ?? true
        container["activityTypeConfidenceScore"] = activityTypeConfidenceScore
        
        // Backupable
        container["backupLastSaved"] = backupLastSaved
    }

    // MARK: - Codable

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // ArcItem
        self.hkStepCount = try? container.decode(Int.self, forKey: .hkStepCount)
        self.activeEnergyBurned = try? container.decode(Double.self, forKey: .activeEnergyBurned)
        self.averageHeartRate = try? container.decode(Double.self, forKey: .averageHeartRate)
        self.maxHeartRate = try? container.decode(Double.self, forKey: .maxHeartRate)

        // ArcPath
        self._manualActivityType = try container.decode(Bool.self, forKey: .manualActivityType)
        self._uncertainActivityType = try container.decode(Bool.self, forKey: .uncertainActivityType)
        self.activityTypeConfidenceScore = try container.decode(Double.self, forKey: .activityTypeConfidenceScore)

        // PersistentPath
        try super.init(from: decoder)
    }

    override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        // ArcItem
        if activeEnergyBurned != nil { try container.encode(activeEnergyBurned, forKey: .activeEnergyBurned) }
        if averageHeartRate != nil { try container.encode(averageHeartRate, forKey: .averageHeartRate) }
        if maxHeartRate != nil { try container.encode(maxHeartRate, forKey: .maxHeartRate) }
        if hkStepCount != nil { try container.encode(hkStepCount, forKey: .hkStepCount) }

        // ArcPath
        if _manualActivityType != nil { try container.encode(_manualActivityType, forKey: .manualActivityType) }
        if _uncertainActivityType != nil { try container.encode(_uncertainActivityType, forKey: .uncertainActivityType) }
        try container.encode(activityTypeConfidenceScore, forKey: .activityTypeConfidenceScore)

        if !notes.isEmpty { try container.encode(notes, forKey: .notes) }

        try super.encode(to: encoder)
    }

    enum CodingKeys: String, CodingKey {

        // ArcItem
        case notes
        case activeEnergyBurned
        case averageHeartRate
        case maxHeartRate
        case hkStepCount

        // ArcPath
        case manualActivityType
        case uncertainActivityType
        case activityTypeConfidenceScore
    }

}
