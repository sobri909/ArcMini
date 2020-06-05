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
    static var recorder: TimelineRecorder { return highlander.recorder }

    // MARK: -

    private(set) var recorder = TimelineRecorder(store: store, classifier: UserTimelineClassifier.highlander)
    var loco: LocomotionManager { return LocomotionManager.highlander }
    var currentVisit: ArcVisit? { return recorder.currentVisit as? ArcVisit }

    var sleepStart: Date?
    var sleepTime: TimeInterval = 0

    // MARK: - Init

    private init() {
        when(loco, does: .willStartSleepMode) { _ in
            self.willStartSleeping()
        }
        when(loco, does: .wentFromSleepModeToRecording) { _ in
            self.didStartSleeping()
        }

        when(loco, does: .recordingStateChanged) { _ in
            Settings.highlander.appGroup.save()
        }
    }

    func startRecording() {
        defer { Settings.highlander.appGroup.save() }

        guard Settings.recordingOn else { return }
        guard Settings.shouldAttemptToUseCoreMotion else { return }

        if Settings.highlander.appGroup.needARecorder {
            recorder.startRecording()
        } else {
            LocomotionManager.highlander.startStandby()
        }

        // start the safety nets
        loco.locationManager.startMonitoringVisits()
        loco.locationManager.startMonitoringSignificantLocationChanges()
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
