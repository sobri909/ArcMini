//
//  TimelineState.swift
//  Arc Mini
//
//  Created by Matt Greenfield on 31/3/20.
//  Copyright © 2020 Matt Greenfield. All rights reserved.
//

import LocoKit

class TimelineState: ObservableObject {

    @Published var timelineSegments: Array<TimelineSegment> = []

    init() {
        if let dateRange = Calendar.current.dateInterval(of: .day, for: Date()) {
            let todaySegment = RecordingManager.store.segment(for: dateRange)
            timelineSegments.append(todaySegment)
        }
    }

    func sceneDidBecomeActive() {
        for segment in timelineSegments {
            segment.startUpdating()
        }
    }

    func sceneDidEnterBackground() {
        for segment in timelineSegments {
            segment.stopUpdating()
        }
    }

}
