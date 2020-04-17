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
    static let recorder = TimelineRecorder(store: store, classifier: UserTimelineClassifier.highlander)

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
        when(loco, does: .didStartSleepMode) { _ in
            self.didStartSleeping()
        }
    }

    // MARK: - Recording state changes
    
    func willStartSleeping() {
        sleepStart = Date()
        if let currentVisit = currentVisit, !currentVisit.hasPlace {
            currentVisit.findAPlace()
        }
    }

    func didStartSleeping() {
        TasksManager.highlander.scheduleBackgroundTasks()
    }

}
