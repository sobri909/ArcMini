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
        case placeModelUpdates = "com.bigpaua.placeModelUpdates"
        case activityTypeModelUpdates = "com.bigpaua.activityTypeModelUpdates"
        case updateTrustFactors = "com.bigpaua.updateTrustFactors"
        case sanitiseStore = "com.bigpaua.sanitiseStore"
        case iCloudDriveBackups = "com.bigpaua.iCloudDriveBackups"
        
        // Arc v3 only
        case activitySummaryUpdates = "com.bigpaua.LearnerCoacher.activitySummaryUpdates"
        case simpleItemUpdates = "com.bigpaua.LearnerCoacher.simpleItemUpdates"
        case cloudKitBackups = "com.bigpaua.LearnerCoacher.cloudKitBackups"
        case dailyAutoExportUpdates = "com.bigpaua.LearnerCoacher.dailyAutoExportUpdates"
        case monthlyAutoExportUpdates = "com.bigpaua.LearnerCoacher.monthlyAutoExportUpdates"
        case wakeupCheck = "com.bigpaua.LearnerCoacher.wakeupCheck"
    }

    enum TaskState: String, Codable {
        case registered, scheduled, running, expired, unfinished, completed
    }

    struct TaskStatus: Codable {
        var state: TaskState
        var lastUpdated: Date
        var minimumDelay: TimeInterval
        var lastCompleted: Date?
    }

    // MARK: -

    static let highlander = TasksManager()

    private(set) var taskStates: [TaskIdentifier: TaskStatus] = [:]
    private(set) var activeTasks: [TaskIdentifier: BGTask] = [:]
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private init() {
        loadStates()
        flushRunning()
    }

    // MARK: -

    func registerBackgroundTasks() {
        register(.placeModelUpdates, minimumDelay: .oneHour) { task in
            TasksManager.update(.placeModelUpdates, to: .running)
            PlaceCache.cache.updateQueuedPlaces(task: task as! BGProcessingTask)
        }

        register(.activityTypeModelUpdates, minimumDelay: .oneHour) { task in
            TasksManager.update(.activityTypeModelUpdates, to: .running)
            UserActivityTypesCache.highlander.updateQueuedModels(task: task as! BGProcessingTask)
        }

        register(.updateTrustFactors, minimumDelay: .oneDay, queue: Jobs.highlander.secondaryQueue.underlyingQueue) { task in
            TasksManager.update(.updateTrustFactors, to: .running)
            RecordingManager.store.connectToDatabase()
            (LocomotionManager.highlander.coordinateAssessor as? CoordinateTrustManager)?.updateTrustFactors()
            RecordingManager.safelyDisconnectFromDatabase()
            TasksManager.update(.updateTrustFactors, to: .completed)
            task.setTaskCompleted(success: true)
        }

        register(.sanitiseStore, minimumDelay: .oneHour, queue: Jobs.highlander.secondaryQueue.underlyingQueue) { task in
            TasksManager.update(.sanitiseStore, to: .running)
            RecordingManager.store.connectToDatabase()
            TimelineProcessor.sanitise(store: RecordingManager.store)
            RecordingManager.safelyDisconnectFromDatabase()
            TasksManager.update(.sanitiseStore, to: .completed)
            task.setTaskCompleted(success: true)
        }

        register(.iCloudDriveBackups, minimumDelay: Backups.maximumBackupFrequency) { task in
            TasksManager.start(.iCloudDriveBackups, with: task)
            Backups.runBackups()
        }
    }

    func scheduleBackgroundTasks() {
        let loco = LocomotionManager.highlander
        if loco.recordingState == .recording { return }

        if Settings.backupsOn {
            TasksManager.schedule(.iCloudDriveBackups, requiresPower: true)
        }

        /* generic tasks */

        if RecordingManager.store.placesPendingUpdate > 0 {
            TasksManager.schedule(.placeModelUpdates, requiresPower: true)
        }

        if RecordingManager.store.modelsPendingUpdate > 0 {
            TasksManager.schedule(.activityTypeModelUpdates, requiresPower: true)
            TasksManager.schedule(.updateTrustFactors, requiresPower: true)
        }

        TasksManager.schedule(.sanitiseStore, requiresPower: true)
    }

    static func scheduleRefresh(_ identifier: TaskIdentifier, after delay: TimeInterval? = nil) {
        onMain {
            let request = BGAppRefreshTaskRequest(identifier: identifier.rawValue)
            if let delay = delay { request.earliestBeginDate = Date(timeIntervalSinceNow: delay) }

            do {
                try BGTaskScheduler.shared.submit(request)
            } catch {
                logger.error("Failed to schedule \(identifier.rawValue.split(separator: ".").last!)")
            }
        }

        highlander.update(identifier, to: .scheduled)
    }

    static func schedule(_ identifier: TaskIdentifier, requiresPower: Bool, requiresNetwork: Bool = false) {
        guard currentState(of: identifier) != .running else {
            logger.info("\(identifier.rawValue.split(separator: ".").last!) is already running", subsystem: .tasks)
            return
        }

        guard currentState(of: identifier) != .scheduled else { return }

        onMain {
            guard let currentStatus = highlander.taskStates[identifier] else { fatalError("Task not registered") }

            let request = BGProcessingTaskRequest(identifier: identifier.rawValue)
            if currentStatus.minimumDelay > 0, let lastCompleted = currentStatus.lastCompleted {
                request.earliestBeginDate = lastCompleted + currentStatus.minimumDelay
            }
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
    
    static func start(_ identifier: TaskIdentifier, with bgTask: BGTask) {
        highlander.update(identifier, to: .running)
        highlander.activeTasks[identifier] = bgTask
    }

    static func update(_ identifier: TaskIdentifier, to state: TaskState) {
        highlander.update(identifier, to: state)
    }

    static func currentState(of identifier: TaskIdentifier) -> TaskState? {
        return highlander.taskStates[identifier]?.state
    }
    
    static func lastCompleted(for identifier: TaskIdentifier) -> Date? {
        return highlander.taskStates[identifier]?.lastCompleted
    }

    // MARK: -

    static var haveTasksRunning: Bool {
        for task in highlander.taskStates.values {
            if task.state == .running { return true }
        }
        return false
    }

    // MARK: -

    private func register(_ identifier: TaskIdentifier, minimumDelay: TimeInterval = 0, queue: DispatchQueue? = nil, launchHandler: @escaping (BGTask) -> Void) {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: identifier.rawValue, using: queue, launchHandler: launchHandler)
        if let status = self.taskStates[identifier] {
            self.taskStates[identifier] = TaskStatus(state: status.state, lastUpdated: Date(), minimumDelay: minimumDelay,
                                                     lastCompleted: status.lastCompleted)
        } else {
            self.taskStates[identifier] = TaskStatus(state: .registered, lastUpdated: Date(), minimumDelay: minimumDelay)
        }
        saveStates()
    }

    private func update(_ identifier: TaskIdentifier, to state: TaskState) {
        onMain {
            guard let status = self.taskStates[identifier] else { fatalError("Task not registered") }
            if state == .completed {
                self.taskStates[identifier] =
                    TaskStatus(state: state, lastUpdated: Date(), minimumDelay: status.minimumDelay, lastCompleted: Date())
            } else {
                self.taskStates[identifier] =
                    TaskStatus(state: state, lastUpdated: Date(), minimumDelay: status.minimumDelay,
                               lastCompleted: status.lastCompleted)
            }
            self.saveStates()

            if state == .unfinished {
                logger.error("\(state.rawValue): \(identifier.rawValue.split(separator: ".").last!)")
                
            } else if state != status.state {
                logger.info("\(state.rawValue): \(identifier.rawValue.split(separator: ".").last!)", subsystem: .tasks)
            }
        }
    }

    // MARK: -

    private func saveStates() {
        do {
            if let groupDefaults = LocomotionManager.highlander.appGroup?.groupDefaults {
                groupDefaults.set(try encoder.encode(taskStates), forKey: "taskStates")
            } else {
                Settings.highlander[.taskStates] = try encoder.encode(taskStates)
            }
        } catch {
            logger.error("\(error)")
        }
    }

    private func loadStates() {
        guard let data = storedStates else { return }
        do {
            self.taskStates = try decoder.decode([TaskIdentifier: TaskStatus].self, from: data)
        } catch {
            logger.error("\(error)")
        }
    }
    
    private var storedStates: Data? {
        if let data = LocomotionManager.highlander.appGroup?.groupDefaults?.value(forKey: "taskStates") as? Data { return data }
        return Settings.highlander[.taskStates] as? Data
    }

    private func flushRunning() {
        let failed = taskStates.filter { $0.value.state == .running }
        for identifier in failed.keys {
            update(identifier, to: .unfinished)
        }
    }

}
