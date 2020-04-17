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
        case scheduled, running, completed
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
        logger.info("taskStates: \(self.taskStates)")
    }

    // MARK: -

    func registerBackgroundTasks() {
        register(.placeModelUpdates) { task in
            logger.info("UPDATE QUEUED PLACES: START")
            PlaceCache.cache.updateQueuedPlaces(task: task as! BGProcessingTask)
        }

        register(.activityTypeModelUpdates) { task in
            logger.info("UPDATE QUEUED MODELS: START")
            UserActivityTypesCache.highlander.updateQueuedModels(task: task as! BGProcessingTask)
        }

        register(.updateTrustFactors, queue: Jobs.highlander.secondaryQueue.underlyingQueue) { task in
            logger.info("UPDATE TRUST FACTORS: START")
            (LocomotionManager.highlander.coordinateAssessor as? CoordinateTrustManager)?.updateTrustFactors()
            logger.info("UPDATE TRUST FACTORS: COMPLETED")
            task.setTaskCompleted(success: true)
        }

        register(TaskIdentifier.sanitiseStore, queue: Jobs.highlander.secondaryQueue.underlyingQueue) { task in
            logger.info("SANITISE STORE: START")
            TimelineProcessor.sanitise(store: RecordingManager.store)
            task.setTaskCompleted(success: true)
            logger.info("SANITISE STORE: COMPLETED")
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
        let request = BGProcessingTaskRequest(identifier: identifier.rawValue)
        request.requiresNetworkConnectivity = requiresNetwork
        request.requiresExternalPower = requiresPower

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            logger.error("FAILED TO SCHEDULE: \(identifier)")
        }

        highlander.taskStates[identifier] = TaskStatus(state: .scheduled, lastUpdated: Date())
    }

    // MARK: -

    private func register(_ identifier: TaskIdentifier, queue: DispatchQueue? = nil, launchHandler: @escaping (BGTask) -> Void) {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: identifier.rawValue, using: queue, launchHandler: launchHandler)
        saveStates()
    }

    // MARK: -

    private func saveStates() {
        guard let data = try? encoder.encode(taskStates) else { logger.error("ERROR: Failed to save task states"); return }
        Settings.highlander[.taskStates] = data
    }

    private func loadStates() {
        guard let data = Settings.highlander[.taskStates] as? Data else { return }
        if let taskStates = try? decoder.decode([TaskIdentifier: TaskStatus].self, from: data) {
            self.taskStates = taskStates
        }
    }

}
