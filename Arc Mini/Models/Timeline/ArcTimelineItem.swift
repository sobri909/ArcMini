//
//  ArcTimelineItem.swift
//  LearnerCoacher
//
//  Created by Matt Greenfield on 14/12/17.
//  Copyright © 2017 Big Paua. All rights reserved.
//

import LocoKit
import SwiftUI

protocol ArcTimelineItem where Self: TimelineItem {

    var notes: [Note] { get }

    // MARK: - Health

    var lastHealthKitLookup: Date? { get set }
    var activeEnergyBurned: Double? { get set }
    var averageHeartRate: Double? { get set }
    var maxHeartRate: Double? { get set }
    
}

// MARK: - Default implementations

extension ArcTimelineItem {

    var arcStore: ArcStore? { return store as? ArcStore }

    var notes: [Note] {
        guard let dateRange = dateRange else { return [] }
        return RecordingManager.store.notes(where: "date >= :startDate AND date <= :endDate AND deleted = 0 ORDER BY date DESC",
                                            arguments: ["startDate": dateRange.start, "endDate": dateRange.end])
    }

    var startTimeString: String? {
        return startString(dateStyle: .none, timeStyle: .short)
    }

    var endTimeString: String? {
        return endString(dateStyle: .none, timeStyle: .short)
    }

    func startString(dateStyle: DateFormatter.Style = .none, timeStyle: DateFormatter.Style = .short, relative: Bool = false) -> String? {
        guard let startDate = startDate else { return nil }
        return dateString(for: startDate, timeZone: startTimeZone ?? TimeZone.current, dateStyle: dateStyle, timeStyle: timeStyle,
                          relative: relative)
    }

    func endString(dateStyle: DateFormatter.Style = .none, timeStyle: DateFormatter.Style = .short, relative: Bool = false) -> String? {
        guard let endDate = endDate else { return nil }
        return dateString(for: endDate, timeZone: endTimeZone ?? TimeZone.current, dateStyle: dateStyle, timeStyle: timeStyle,
                          relative: relative)
    }

    func dateString(for date: Date, timeZone: TimeZone = TimeZone.current, dateStyle: DateFormatter.Style = .none,
                            timeStyle: DateFormatter.Style = .short, relative: Bool = false) -> String? {
        ArcVisit.titleDateFormatter.timeZone = timeZone
        ArcVisit.titleDateFormatter.doesRelativeDateFormatting = relative
        ArcVisit.titleDateFormatter.dateStyle = dateStyle
        ArcVisit.titleDateFormatter.timeStyle = timeStyle
        return ArcVisit.titleDateFormatter.string(from: date)
    }

    var uiColor: UIColor {
        if self.isDataGap { return .black }
        if let activityType = (self as? ArcPath)?.activityType { return UIColor.color(for: activityType) }
        if let activityType = modeActivityType { return UIColor.color(for: activityType) }
        return UIColor.color(for: .stationary)
    }

    var color: Color { return Color(uiColor) }

    // MARK: - Path brexit

    func brexit(_ brexiter: ItemSegment, completion: ((TimelineItem?) -> Void)? = nil) {
        if isMergeLocked || deleted { return }
        guard let store = store as? ArcStore else { return }

        // should be a visit brexit?
        if brexiter.activityType == .stationary { brexit(brexiter, place: nil); return }

        TimelineProcessor.extractItem(for: brexiter, in: store, completion: completion)
    }

    // MARK: - Visit brexit

    func brexit(_ brexiter: ItemSegment, place: Place?) {
        if isMergeLocked || deleted { return }
        guard let store = store as? ArcStore else { return }

        store.process {
            if self.deleted || self.nextItem?.deleted == true || self.previousItem?.deleted == true { return }
            if self.isMergeLocked || self.nextItem?.isMergeLocked == true || self.previousItem?.isMergeLocked == true { return }

            // brexiting a visit from a visit with the same place? that's a waste of time
            if let visit = self as? ArcVisit, place != nil, place?.placeId == visit.placeId { return }

            TimelineProcessor.extractItem(for: brexiter, in: store) { newItem in
                if let place = place, let newItem = newItem as? ArcVisit {
                    newItem.usePlace(place, manualPlace: true)
                }
            }
        }
    }

}

