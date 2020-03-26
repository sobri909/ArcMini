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
    var title: String { get }
}

// MARK: - Default implementations

extension ArcTimelineItem {

    var arcStore: ArcStore? { return store as? ArcStore }

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

}

