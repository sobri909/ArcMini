//
//  Calendar+extensions.swift
//  Arc Mini
//
//  Created by Matt Greenfield on 7/4/20.
//  Copyright © 2020 Matt Greenfield. All rights reserved.
//

import Foundation

enum Weekday: Int, CaseIterable {
    case all = 0
    case sunday = 1
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6
    case saturday = 7
}

let greg = Calendar(identifier: Calendar.Identifier.gregorian)

extension Date {
    var isToday: Bool { return Calendar.current.isDateInToday(self) }
    var isYesterday: Bool { return Calendar.current.isDateInYesterday(self) }
    var isTomorrow: Bool { return Calendar.current.isDateInTomorrow(self) }
    var nextDay: Date { return Calendar.current.date(byAdding: .day, value: 1, to: self)! }
    var previousDay: Date { return Calendar.current.date(byAdding: .day, value: -1, to: self)! }
    var weekday: Weekday { return Weekday(rawValue: greg.dateComponents([.weekday], from: self).weekday!)! }
}

extension DateInterval: Identifiable {
    public var id: Int { return hashValue }

    var middle: Date { return start + duration * 0.5 }

    static func range(of rangeType: Calendar.Component, for date: Date) -> DateInterval? {
        let acceptable: [Calendar.Component] = [.day, .weekOfYear, .month, .year]
        guard acceptable.contains(rangeType) else { return nil }
        return Calendar.current.dateInterval(of: rangeType, for: date)
    }

    func nextRange(of rangeType: Calendar.Component) -> DateInterval? {
        let acceptable: [Calendar.Component] = [.day, .weekOfYear, .month, .year]
        guard acceptable.contains(rangeType) else { return nil }
        return DateInterval.range(of: rangeType, for: end.addingTimeInterval(.oneHour))
    }

    func previousRange(of rangeType: Calendar.Component) -> DateInterval? {
        let acceptable: [Calendar.Component] = [.day, .weekOfYear, .month, .year]
        guard acceptable.contains(rangeType) else { return nil }
        return DateInterval.range(of: rangeType, for: start.addingTimeInterval(-.oneHour))
    }

    var shortDurationString: String {
        return String(duration: duration, style: .short)
    }
}
