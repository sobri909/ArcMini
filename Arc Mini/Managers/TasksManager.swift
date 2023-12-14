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
        case updateTrustFactors = "com.bigpaua.ArcMini.updateTrustFactors"
        case sanitiseStore = "com.bigpaua.ArcMini.sanitiseStore"
        case iCloudDriveBackups = "com.bigpaua.ArcMini.iCloudDriveBackups"
        case coreMLModelUpdates = "com.bigpaua.ArcMini.coreMLModelUpdates"
        
        // Arc v3 only
        case activitySummaryUpdates = "com.bigpaua.ArcMini.activitySummaryUpdates"
        case simpleItemUpdates = "com.bigpaua.ArcMini.simpleItemUpdates"
        case dailyAutoExportUpdates = "com.bigpaua.ArcMini.dailyAutoExportUpdates"
        case monthlyAutoExportUpdates = "com.bigpaua.ArcMini.monthlyAutoExportUpdates"
        case wakeupCheck = "com.bigpaua.ArcMini.wakeupCheck"
        
        var shortName: String { String(rawValue.split(separator: ".").last!) }

        static let deprecatedIdentifiers = [
            "cloudKitBackups", "placeModelUpdates2", "coreMLModelUpdate", "activityTypeModelUpdates", "housekeepCloudKit"
        ]

        init?(shortName: String) {
            self.init(rawValue: "com.bigpaua.ArcMini." + shortName)
        }
    }

    enum TaskState: String, Codable {
        case registered, scheduled, running, expired, unfinished, completed
        var sortIndex: Int {
            switch self {
            case .running: return 0
            case .expired: return 1
            case .unfinished: return 2
            case .completed: return 3
            case .scheduled: return 4
            case .registered: return 5
            }
        }
    }

    struct TaskStatus: Codable, Identifiable {
        var shortName: String
        var state: TaskState
        var minimumDelay: TimeInterval
        var lastUpdated: Date
        var lastStarted: Date?
        var lastExpired: Date?
        var lastCompleted: Date?
        var lastRanInApp: String?
        var id: String { return shortName }
        var overdueBy: TimeInterval {
            guard let lastCompleted else { return 0 }
            return lastCompleted.age - minimumDelay
        }
    }

    // MARK: -

    static let highlander = TasksManager()

    private(set) var taskStates: [String: TaskStatus] = [:]
    private(set) var activeTasks: [TaskIdentifier: BGTask] = [:]
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let mutex = PThreadMutex(type: .recursive)

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

        register(.coreMLModelUpdates, minimumDelay: .oneHour) { task in
            TasksManager.update(.coreMLModelUpdates, to: .running)
            RecordingManager.store.connectToDatabase()
            CoreMLModelUpdater.highlander.updateQueuedModels(
                task: task as! BGProcessingTask, currentClassifier: RecordingManager.highlander.recorder.classifier
            ) { expired in
                TasksManager.update(.coreMLModelUpdates, to: expired ? .expired : .completed)
                TasksManager.highlander.scheduleBackgroundTasks()
                RecordingManager.safelyDisconnectFromDatabase()
            }
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
            task.expirationHandler = {
                TasksManager.update(.sanitiseStore, to: .expired)
                task.setTaskCompleted(success: false)
            }
            
            TasksManager.update(.sanitiseStore, to: .running)
            RecordingManager.store.connectToDatabase()
            TimelineProcessor.sanitise(store: RecordingManager.store)
            RecordingManager.store.housekeep()
            RecordingManager.safelyDisconnectFromDatabase()
            
            if TasksManager.currentState(of: .sanitiseStore) == .expired {
                task.setTaskCompleted(success: false)
            } else {
                TasksManager.update(.sanitiseStore, to: .completed)
                task.setTaskCompleted(success: true)
            }
        }

        register(.iCloudDriveBackups, minimumDelay: Backups.maximumBackupFrequency) { task in
            TasksManager.start(.iCloudDriveBackups, with: task)
            Backups.runBackups()
        }
    }

    func scheduleBackgroundTasks() {
        if LocomotionManager.highlander.recordingState == .recording { return }

//        if Settings.backupsOn {
//            TasksManager.schedule(.iCloudDriveBackups, requiresPower: true)
//        }

        /* generic tasks */

        if RecordingManager.store.placesPendingUpdate > 0 {
            TasksManager.schedule(.placeModelUpdates, requiresPower: true)
        }

        if RecordingManager.store.coreMLModelsPendingUpdate > 0 {
            TasksManager.schedule(.coreMLModelUpdates, requiresPower: true)
            TasksManager.schedule(.updateTrustFactors, requiresPower: true)
        }

        TasksManager.schedule(.sanitiseStore, requiresPower: true)
    }


    func updateQueuePriorities() {
        let qos: QualityOfService = LocomotionManager.highlander.applicationState == .active ? .utility : .background
        CoreMLModelUpdater.highlander.updatesQueue.updateQualityOfService(to: qos)
        PlaceCache.cache.updatesQueue.updateQualityOfService(to: qos)
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

        highlander.update(identifier.shortName, to: .scheduled)
    }

    static func schedule(_ identifier: TaskIdentifier, requiresPower: Bool, requiresNetwork: Bool = false) {
        guard currentState(of: identifier) != .running else { return }

        guard let currentStatus = highlander.mutex.sync(execute: { highlander.taskStates[identifier.shortName] }) else { fatalError("Task not registered") }

        onMain {
            let request = BGProcessingTaskRequest(identifier: identifier.rawValue)
            if currentStatus.minimumDelay > 0, let lastCompleted = currentStatus.lastCompleted {
                let earliestBeginDate = lastCompleted + currentStatus.minimumDelay
                if earliestBeginDate > Date() { // only bother with this if it's a date in the future
                    request.earliestBeginDate = earliestBeginDate
                }
            }
            request.requiresNetworkConnectivity = requiresNetwork
            request.requiresExternalPower = requiresPower

            do {
                try BGTaskScheduler.shared.submit(request)
            } catch {
                logger.error("Failed to schedule \(identifier.rawValue.split(separator: ".").last!)")
            }
        }

        highlander.update(identifier.shortName, to: .scheduled)
    }
    
    static func start(_ identifier: TaskIdentifier, with bgTask: BGTask) {
        highlander.update(identifier.shortName, to: .running)
        highlander.mutex.sync { highlander.activeTasks[identifier] = bgTask }
    }

    static func update(_ identifier: TaskIdentifier, to state: TaskState) {
        highlander.update(identifier.shortName, to: state)
    }

    static func currentState(of identifier: TaskIdentifier) -> TaskState? {
        return highlander.mutex.sync { highlander.taskStates[identifier.shortName]?.state }
    }
    
    static func lastCompleted(for identifier: TaskIdentifier) -> Date? {
        return highlander.mutex.sync { highlander.taskStates[identifier.shortName]?.lastCompleted }
    }

    // MARK: -

    static var haveTasksRunning: Bool {
        let taskStates = highlander.mutex.sync { highlander.taskStates }
        for task in taskStates.values {
            if task.state == .running { return true }
        }
        return false
    }

    // MARK: -

    private func register(_ identifier: TaskIdentifier, minimumDelay: TimeInterval = 0, queue: DispatchQueue? = nil, launchHandler: @escaping (BGTask) -> Void) {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: identifier.rawValue, using: queue, launchHandler: launchHandler)
        if let status = taskStates[identifier.shortName] {
            mutex.sync {
                taskStates[identifier.shortName] = TaskStatus(
                    shortName: identifier.shortName, state: status.state, minimumDelay: minimumDelay,
                    lastUpdated: .now,
                    lastStarted: status.lastStarted,
                    lastExpired: status.lastExpired,
                    lastCompleted: status.lastCompleted,
                    lastRanInApp: status.lastRanInApp
                )
            }
        } else {
            mutex.sync {
                taskStates[identifier.shortName] = TaskStatus(
                    shortName: identifier.shortName, state: .registered, minimumDelay: minimumDelay,
                    lastUpdated: .now
                )
            }
        }
        saveStates()
    }

    private func update(_ shortName: String, to state: TaskState) {
        guard let identifier = TaskIdentifier(shortName: shortName) else { fatalError("Unknown task identifier: \(shortName)") }
        guard let status = mutex.sync(execute: { taskStates[identifier.shortName] }) else { fatalError("Task not registered") }

        mutex.sync {
            switch state {
            case .running:
                taskStates[identifier.shortName] = TaskStatus(
                    shortName: identifier.shortName, state: state, minimumDelay: status.minimumDelay,
                    lastUpdated: .now,
                    lastStarted: .now,
                    lastExpired: status.lastExpired,
                    lastCompleted: status.lastCompleted,
                    lastRanInApp: "Arc Mini"
                )
            case .expired:
                taskStates[identifier.shortName] = TaskStatus(
                    shortName: identifier.shortName, state: state, minimumDelay: status.minimumDelay,
                    lastUpdated: .now,
                    lastStarted: status.lastStarted,
                    lastExpired: .now,
                    lastCompleted: status.lastCompleted,
                    lastRanInApp: status.lastRanInApp
                )
            case .completed:
                taskStates[identifier.shortName] = TaskStatus(
                    shortName: identifier.shortName, state: state, minimumDelay: status.minimumDelay,
                    lastUpdated: .now,
                    lastStarted: status.lastStarted,
                    lastExpired: status.lastExpired,
                    lastCompleted: .now,
                    lastRanInApp: status.lastRanInApp
                )
            default:
                taskStates[identifier.shortName] = TaskStatus(
                    shortName: identifier.shortName, state: state, minimumDelay: status.minimumDelay,
                    lastUpdated: .now,
                    lastStarted: status.lastStarted,
                    lastExpired: status.lastExpired,
                    lastCompleted: status.lastCompleted,
                    lastRanInApp: status.lastRanInApp
                )
            }

            if state != .running {
                activeTasks[identifier] = nil
            }
        }
        saveStates()

        if state == .unfinished {
            logger.error("\(state.rawValue): \(identifier.rawValue.split(separator: ".").last!)")
            
        } else if state != status.state {
            logger.info("\(state.rawValue): \(identifier.rawValue.split(separator: ".").last!)", subsystem: .tasks)
        }
    }

    // MARK: -

    private func saveStates() {
        do {
            if let groupDefaults = LocomotionManager.highlander.appGroup?.groupDefaults {
                try mutex.sync { groupDefaults.set(try encoder.encode(taskStates), forKey: "taskStates") }
            } else {
                try mutex.sync { Settings.highlander[.taskStates] = try encoder.encode(taskStates) }
            }
        } catch {
            logger.error("\(error)")
        }
    }

    private func loadStates() {
        guard let data = storedStates else { return }
        do {
            try mutex.sync { taskStates = try decoder.decode([String: TaskStatus].self, from: data) }
        } catch {
            logger.error("\(error)")
        }
    }
    
    private var storedStates: Data? {
        if let data = LocomotionManager.highlander.appGroup?.groupDefaults?.value(forKey: "taskStates") as? Data { return data }
        return Settings.highlander[.taskStates] as? Data
    }

    private func flushRunning() {
        let failed = mutex.sync { taskStates.filter { $0.value.state == .running && $0.value.lastRanInApp == "Arc Mini" } }
        for shortName in failed.keys {
            guard TaskIdentifier(shortName: shortName) != nil else { continue }
            update(shortName, to: .unfinished)
        }
    }

}

extension OperationQueue {
    func updateQualityOfService(to qos: QualityOfService) {
        qualityOfService = qos
        operations.forEach { $0.qualityOfService = qos }
    }
}
