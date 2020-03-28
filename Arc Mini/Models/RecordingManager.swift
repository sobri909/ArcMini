//
//  RecordingManager.swift
//  Arc Mini
//
//  Created by Matt Greenfield on 28/3/20.
//  Copyright © 2020 Matt Greenfield. All rights reserved.
//

import LocoKit
import SwiftNotes

class RecordingManager {

    static let highlander = RecordingManager()

    // MARK: -

    static let store = ArcStore()
    static let recorder = TimelineRecorder(store: store, classifier: TimelineClassifier.highlander)

    // MARK: -

    var recorder: TimelineRecorder { return RecordingManager.recorder }
    var loco: LocomotionManager { return LocomotionManager.highlander }
    var currentVisit: ArcVisit? { return recorder.currentVisit as? ArcVisit }

    var sleepStart: Date?
    var sleepTime: TimeInterval = 0

    // MARK: - Init

    private init() {
        when(loco, does: .willStartSleepMode) { _ in
              self.willStartSleeping()
          }
    }

    // MARK: -

    private var _todaySegment: TimelineSegment?
    var todaySegment: TimelineSegment {
        // flush outdated
        if let dateRange = _todaySegment?.dateRange, !dateRange.containsNow { _todaySegment = nil }

        // create if missing
        if _todaySegment == nil {
            _todaySegment = RecordingManager.store.segment(for: Calendar.current.dateInterval(of: .day, for: Date())!)
        }

        return _todaySegment!
    }

    // MARK: - Recording state changes
    
    func willStartSleeping() {
        sleepStart = Date()

        // find a place for the visit
        if let currentVisit = currentVisit, !currentVisit.hasPlace {
            currentVisit.findAPlace()
        }
    }

}
