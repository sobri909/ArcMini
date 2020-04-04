//
//  TimelineState.swift
//  Arc Mini
//
//  Created by Matt Greenfield on 31/3/20.
//  Copyright © 2020 Matt Greenfield. All rights reserved.
//

import LocoKit

class TimelineState: ObservableObject {

    @Published var dateRanges: Array<DateInterval> = []
    @Published var currentCardIndex = 0

    init() {
        dateRanges.append(Calendar.current.dateInterval(of: .day, for: Date().previousDay)!)
        dateRanges.append(Calendar.current.dateInterval(of: .day, for: Date())!)
    }

    var visibleDateRange: DateInterval? {
        guard currentCardIndex < dateRanges.count else { return nil }
        return dateRanges[currentCardIndex]
    }

    var visibleTimelineSegment: TimelineSegment? {
        guard let dateRange = visibleDateRange else { return nil }
        return RecordingManager.store.segment(for: dateRange)
    }

    func sceneDidBecomeActive() {
//        for segment in timelineSegments {
//            segment.startUpdating()
//        }
    }

    func sceneDidEnterBackground() {
//        for segment in timelineSegments {
//            segment.stopUpdating()
//        }
    }

}
