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

    static let maximumSleepCycleDuration: TimeInterval = 60
    static let minimumSleepCycleDuration: TimeInterval = 12
    static let fallbackSleepCycleDuration: TimeInterval = 30

    // MARK: -

    static let highlander = RecordingManager()

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
    }

    func startRecording() {
        guard Settings.recordingOn else { return }
        guard Settings.shouldAttemptToUseCoreMotion else { return }

        if let appGroup = loco.appGroup, appGroup.haveMultipleRecorders {
            if appGroup.shouldBeTheRecorder {
                recorder.startRecording()
            } else {
                LocomotionManager.highlander.startStandby()
            }
        } else {
            recorder.startRecording()
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

        // make sure the sleep cycle is the right size
        loco.sleepCycleDuration = RecordingManager.sleepCycleDuration

        // prepare for the next wakeup
        loco.ignoreNoLocationDataDuringWakeups = shouldIgnoreNolos
    }

    func didStartSleeping() {
        TasksManager.highlander.scheduleBackgroundTasks()
    }

    // MARK: - Sleep cycle management

    var shouldIgnoreNolos: Bool {

        // no leaving probability? must be not enough data, so don't risk it
        guard let leavingProbabilityNow = currentVisit?.leavingProbabilityNow else { return false }

        // more likely to be leaving soon than not? then shouldn't ignore nolos
        return leavingProbabilityNow > 0.5
    }

    static var sleepCycleDuration: TimeInterval {
        guard let nowProb = highlander.currentVisit?.leavingProbabilityNow else {
            return RecordingManager.fallbackSleepCycleDuration
        }

        let logProb = log10(1.0 / nowProb)
        let duration = RecordingManager.maximumSleepCycleDuration * logProb

        return duration.clamped(min: RecordingManager.minimumSleepCycleDuration, max: RecordingManager.maximumSleepCycleDuration)
    }

    // MARK: -

    static func safelyDisconnectFromDatabase() {
        let loco = LocomotionManager.highlander
        if loco.applicationState != .active, !loco.recordingState.isCurrentRecorder, !TasksManager.haveTasksRunning {
            store.disconnectFromDatabase()
        }
    }

}
