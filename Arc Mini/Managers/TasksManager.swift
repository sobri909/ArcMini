//
//  TasksManager.swift
//  Arc Mini
//
//  Created by Matt Greenfield on 17/4/20.
//  Copyright © 2020 Matt Greenfield. All rights reserved.
//

import BackgroundTasks
import LocoKit

class TasksManager {

    enum TaskIdentifier: String, Codable {
        case placeModelUpdates = "com.bigpaua.ArcMini.placeModelUpdates"
        case activityTypeModelUpdates = "com.bigpaua.ArcMini.activityTypeModelUpdates"
        case updateTrustFactors = "com.bigpaua.ArcMini.updateTrustFactors"
        case sanitiseStore = "com.bigpaua.ArcMini.sanitiseStore"
    }

    enum TaskState: String, Codable {
        case scheduled, running, expired, unfinished, completed
    }

    struct TaskStatus: Codable {
        var state: TaskState
        var lastUpdated: Date
    }

    // MARK: -

    static let highlander = TasksManager()

    private(set) var taskStates: [TaskIdentifier: TaskStatus] = [:]
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private init() {
        loadStates()
        flushRunning()
    }

    // MARK: -

    func registerBackgroundTasks() {
        register(.placeModelUpdates) { task in
            TasksManager.update(.placeModelUpdates, to: .running)
            PlaceCache.cache.updateQueuedPlaces(task: task as! BGProcessingTask)
        }

        register(.activityTypeModelUpdates) { task in
            TasksManager.update(.activityTypeModelUpdates, to: .running)
            UserActivityTypesCache.highlander.updateQueuedModels(task: task as! BGProcessingTask)
        }

        register(.updateTrustFactors, queue: Jobs.highlander.secondaryQueue.underlyingQueue) { task in
            TasksManager.update(.updateTrustFactors, to: .running)
            (LocomotionManager.highlander.coordinateAssessor as? CoordinateTrustManager)?.updateTrustFactors()
            TasksManager.update(.updateTrustFactors, to: .completed)
            task.setTaskCompleted(success: true)
        }

        register(.sanitiseStore, queue: Jobs.highlander.secondaryQueue.underlyingQueue) { task in
            TasksManager.update(.sanitiseStore, to: .running)
            TimelineProcessor.sanitise(store: RecordingManager.store)
            TasksManager.update(.sanitiseStore, to: .completed)
            task.setTaskCompleted(success: true)
        }
    }

    func scheduleBackgroundTasks() {
        if LocomotionManager.highlander.recordingState == .recording { return }

        if RecordingManager.store.placesPendingUpdate > 0 {
            TasksManager.schedule(.placeModelUpdates, requiresPower: true)
        }

        if RecordingManager.store.modelsPendingUpdate > 0 {
            TasksManager.schedule(.activityTypeModelUpdates, requiresPower: true)
            TasksManager.schedule(.updateTrustFactors, requiresPower: true)
        }

        TasksManager.schedule(.sanitiseStore, requiresPower: true)
    }

    static func schedule(_ identifier: TaskIdentifier, requiresPower: Bool, requiresNetwork: Bool = false) {
        guard currentState(of: identifier) != .running else {
            logger.info("\(identifier.rawValue.split(separator: ".").last!) is already running")
            return
        }

        onMain {
            let request = BGProcessingTaskRequest(identifier: identifier.rawValue)
            request.requiresNetworkConnectivity = requiresNetwork
            request.requiresExternalPower = requiresPower

            do {
                try BGTaskScheduler.shared.submit(request)
            } catch {
                logger.error("Failed to schedule \(identifier.rawValue.split(separator: ".").last!)")
            }
        }

        highlander.update(identifier, to: .scheduled)
    }

    static func update(_ identifier: TaskIdentifier, to state: TaskState) {
        highlander.update(identifier, to: state)
    }

    static func currentState(of identifier: TaskIdentifier) -> TaskState? {
        return highlander.taskStates[identifier]?.state
    }

    // MARK: -

    private func register(_ identifier: TaskIdentifier, queue: DispatchQueue? = nil, launchHandler: @escaping (BGTask) -> Void) {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: identifier.rawValue, using: queue, launchHandler: launchHandler)
        saveStates()
    }

    private func update(_ identifier: TaskIdentifier, to state: TaskState) {
        onMain {
            self.taskStates[identifier] = TaskStatus(state: state, lastUpdated: Date())
            self.saveStates()
        }
        if state == .unfinished {
            logger.error("\(state.rawValue.uppercased()): \(identifier.rawValue.split(separator: ".").last!)")
        } else {
            logger.info("\(state.rawValue.uppercased()): \(identifier.rawValue.split(separator: ".").last!)")
        }
    }

    // MARK: -

    private func saveStates() {
        do {
            Settings.highlander[.taskStates] = try encoder.encode(taskStates)
        } catch {
            logger.error("\(error)")
        }
    }

    private func loadStates() {
        guard let data = Settings.highlander[.taskStates] as? Data else { logger.info("No taskStates data in UserDefaults"); return }
        do {
            self.taskStates = try decoder.decode([TaskIdentifier: TaskStatus].self, from: data)
        } catch {
            logger.error("\(error)")
        }
    }

    private func flushRunning() {
        let failed = taskStates.filter { $0.value.state == .running }
        for identifier in failed.keys {
            update(identifier, to: .unfinished)
        }
    }

}
