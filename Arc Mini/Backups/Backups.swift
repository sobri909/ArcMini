//
//  Backups.swift
//  Arc
//
//  Created by Matt Greenfield on 30/9/20.
//  Copyright © 2020 Big Paua. All rights reserved.
//

import LocoKit
import BackgroundTasks

enum Backups {

    static let maximumBackupFrequency: TimeInterval = .oneHour * 3
    static let delayBetweenBatches: TimeInterval = 10
    static let maxConcurrentOperationCount = 4
    
    static let notesBatchSize = 300
    static let placesBatchSize = 300
    static let summariesBatchSize = 40
    static let itemsBatchSize = 100
    static let samplesBatchSize = 1000
    
    // MARK: -
    
    static func runBackups() {
        guard Settings.backupsOn else { return }
        if bgTask == nil, !canBackupWithoutTask { return }
        
        setupTaskExpiryHandler()

        backupQueue.addOperation {
            if bgTask == nil { TasksManager.update(.iCloudDriveBackups, to: .running) }
            
            var notesCount = Int.max, placesCount = Int.max, summariesCount = Int.max, itemsCount = Int.max, samplesCount = Int.max
            
            if backupQueue.operationCount < maxConcurrentOperationCount {
                notesCount = backupNotes()
                placesCount = backupPlaces()
                summariesCount = backupTimelineSummaries()
                itemsCount = backupItems()
            } else {
                print("backupQueue.operationCount: \(backupQueue.operationCount)")
            }
            
            if samplesBackupQueue.operationCount < maxConcurrentOperationCount {
                samplesCount = backupSamples()
            } else {
                print("samplesBackupQueue.operationCount: \(samplesBackupQueue.operationCount)")
            }
            
            // not finished yet?
            guard notesCount == 0, placesCount == 0, itemsCount < 2, summariesCount < 2, samplesCount < 20 else {
                dedupedTask(scope: Settings.highlander, after: delayBetweenBatches) {
                    Backups.runBackups()
                }
                return
            }

            // finished
            finished(success: true)
        }
    }
    
    private static func finished(success: Bool) {
        if TasksManager.currentState(of: .iCloudDriveBackups) == .running {
            if success {
                TasksManager.update(.iCloudDriveBackups, to: .completed)
            } else {
                TasksManager.update(.iCloudDriveBackups, to: .unfinished)
            }
        }
        RecordingManager.safelyDisconnectFromDatabase()
        bgTask?.setTaskCompleted(success: success)
    }
    
    // MARK: -
    
    private static func backupNotes() -> Int {
        let batch = notesBackupBatch
        if batch.count > 0 { logger.info("notesBackupBatch: \(batch.count)", subsystem: .backups) }
        for note in batch {
            backupQueue.addOperation {
                note.backup()
            }
        }
        return batch.count
    }
    
    private static func backupPlaces() -> Int {
        let batch = placesBackupBatch
        if batch.count > 0 { logger.info("placesBackupBatch: \(batch.count)", subsystem: .backups) }
        for place in batch {
            backupQueue.addOperation {
                place.backup()
            }
        }
        return batch.count
    }
    
    private static func backupItems() -> Int {
        let batch = itemsBackupBatch
        if batch.count > 0 { logger.info("itemsBackupBatch: \(batch.count)", subsystem: .backups) }
        for item in batch {
            item.includeSamplesWhenEncoding = false
            backupQueue.addOperation {
                (item as? Backupable)?.backup()
            }
        }
        return batch.count
    }
    
    private static func backupTimelineSummaries() -> Int {
        let batch = summariesBackupBatch
        if batch.count > 0 { logger.info("summariesBackupBatch: \(batch.count)", subsystem: .backups) }
        for summary in batch {
            summary.segment.stopUpdating()
            summary.segment.shouldReclassifySamples = false
            summary.segment.shouldReprocessOnUpdate = false
            backupQueue.addOperation {
                summary.backup()
            }
        }
        return batch.count
    }
    
    private static func backupSamples() -> Int {
        let batch = samplesBackupBatch
        if batch.count > 0 { logger.info("samplesBackupBatch: \(batch.count)", subsystem: .backups) }
        for sample in batch {
            samplesBackupQueue.addOperation {
                sample.backup()
            }
        }
        return batch.count
    }
    
    // MARK: - Counts
    
    static var backupNotesCount: Int {
        return RecordingManager.store.countNotes(
            where: "backupLastSaved IS NULL OR backupLastSaved < lastSaved")
    }

    static var backupPlacesCount: Int {
        return RecordingManager.store.countPlaces(
            where: "(backupLastSaved IS NULL OR backupLastSaved < lastSaved) AND visitsCount > 0")
    }

    static var backupItemsCount: Int {
        return RecordingManager.store.countItems(
            where: "(backupLastSaved IS NULL OR backupLastSaved < lastSaved) AND restoring = 0")
    }

    static var backupSamplesCount: Int {
        return RecordingManager.store.countSamples(
            where: "backupLastSaved IS NULL OR backupLastSaved < lastSaved")
    }

    static var backupTimelineSummariesCount: Int {
        return RecordingManager.store.countTimelineSummaries(
            where: "backupLastSaved IS NULL OR backupLastSaved < lastSaved")
    }
    
    // MARK: - Batches

    private static var notesBackupBatch: [Note] {
        return RecordingManager.store.notes(
            where: "(backupLastSaved IS NULL OR backupLastSaved < lastSaved) LIMIT ?",
            arguments: [notesBatchSize])
    }

    private static var placesBackupBatch: [Place] {
        return RecordingManager.store.places(
            where: "(backupLastSaved IS NULL OR backupLastSaved < lastSaved) AND visitsCount > 0 LIMIT ?",
            arguments: [placesBatchSize])
    }

    private static var itemsBackupBatch: [ArcTimelineItem] {
        RecordingManager.store.saveNoDate()
        let results = RecordingManager.store.items(
            where: "(backupLastSaved IS NULL OR backupLastSaved < lastSaved) AND restoring = 0 LIMIT ?",
            arguments: [itemsBatchSize])
        if results.isEmpty { return [] }
        return results as? [ArcTimelineItem] ?? []
    }

    private static var samplesBackupBatch: [ArcSample] {
        RecordingManager.store.saveNoDate()
        let results = RecordingManager.store.samples(
            where: "(backupLastSaved IS NULL OR backupLastSaved < lastSaved) LIMIT ?",
            arguments: [samplesBatchSize])
        if results.isEmpty { return [] }
        return results as? [ArcSample] ?? []
    }
    
    private static var summariesBackupBatch: [TimelineRangeSummary] {
        return RecordingManager.store.timelineSummaries(
            where: "(backupLastSaved IS NULL OR backupLastSaved < lastSaved) LIMIT ?",
            arguments: [summariesBatchSize])
    }
    
    // MARK: - Foreground backups
    
    static var canBackupWithoutTask: Bool {
        if UIDevice.current.batteryState == .unplugged { return false }
        if ProcessInfo.processInfo.isLowPowerModeEnabled { return false }
        if AppDelegate.thermalState.rawValue >= ProcessInfo.ThermalState.serious.rawValue { return false }
        if LocomotionManager.highlander.recordingState == .recording { return false }
        if LocomotionManager.highlander.applicationState != .active { return false }
        return true
    }
    
    // MARK: - BackgroundTasks
    
    private static var bgTask: BGProcessingTask? {
        return TasksManager.highlander.activeTasks[.iCloudDriveBackups] as? BGProcessingTask
    }
    
    private static func setupTaskExpiryHandler() {
        guard let task = bgTask else { return }
        guard task.expirationHandler == nil else { return }
        
        task.expirationHandler = {
            logger.info("Cancelling operations: \(backupQueue.operations.count)", subsystem: .backups)
            backupQueue.cancelAllOperations()
            samplesBackupQueue.cancelAllOperations()
            bgTaskExpired()
        }
    }
    
    private static func bgTaskExpired() {
        TasksManager.update(.iCloudDriveBackups, to: .expired)
        RecordingManager.safelyDisconnectFromDatabase()
        bgTask?.setTaskCompleted(success: false)
        TasksManager.highlander.scheduleBackgroundTasks()
    }

    // MARK: -
    
    static var backupsDir: URL? {
        return FileManager.default.iCloudDocsDir?
            .appendingPathComponent("Backups", isDirectory: true)
    }
    
    static let backupQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "ArcApp.backupQueue"
        queue.qualityOfService = .background
        queue.maxConcurrentOperationCount = maxConcurrentOperationCount
        return queue
    }()
    
    static let samplesBackupQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "ArcApp.samplesBackupQueue"
        queue.qualityOfService = .background
        queue.maxConcurrentOperationCount = maxConcurrentOperationCount
        return queue
    }()
    
    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
    
}
