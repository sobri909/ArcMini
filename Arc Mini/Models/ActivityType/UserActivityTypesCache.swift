//
//  ActivityTypesCache.swift
//  LearnerCoacher
//
//  Created by Matt Greenfield on 7/03/17.
//  Copyright © 2017 Big Paua. All rights reserved.
//

import LocoKit
import LocoKitCore
import BackgroundTasks
import CoreLocation
import GRDB

final class UserActivityTypesCache: MLModelSource {

    public typealias Model = UserActivityType
    public typealias ParentClassifier = ActivityTypeClassifier

    static var highlander = UserActivityTypesCache()

    var store: ArcStore { return RecordingManager.store }
    let mutex = UnfairLock()

    lazy var updatesQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "ArcMini.UserActivityTypesCache.updatesQueue"
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .background
        return queue
    }()

    public var providesDepths = [2]

    public func modelFor(name: ActivityTypeName, coordinate: CLLocationCoordinate2D, depth: Int) -> UserActivityType? {
        guard providesDepths.contains(depth) else { return nil }

        var query = "SELECT * FROM ActivityTypeModel WHERE isShared = 0 AND name = ? AND depth = ?"
        var arguments: [DatabaseValueConvertible] = [name.rawValue, depth]

        if depth > 0 {
            query += " AND latitudeMin <= ? AND latitudeMax >= ? AND longitudeMin <= ? AND longitudeMax >= ?"
            arguments.append(coordinate.latitude)
            arguments.append(coordinate.latitude)
            arguments.append(coordinate.longitude)
            arguments.append(coordinate.longitude)
        }

        if let model = store.userModel(for: query, arguments: StatementArguments(arguments)) { return model }

        // create model if missing
        if name != .unknown {
            if let model = UserActivityType(name: name, coordinate: coordinate) {
                logger.info("NEW MODEL: [\(model.geoKey)]")
                model.needsUpdate = true
                model.save()
                return model
            }
        }

        return nil
    }

    public func modelsFor(names: [ActivityTypeName], coordinate: CLLocationCoordinate2D, depth: Int) -> [UserActivityType] {
        guard providesDepths.contains(depth) else { return [] }

        var query = "SELECT * FROM ActivityTypeModel WHERE isShared = 0 AND depth = ?"
        var arguments: [DatabaseValueConvertible] = [depth]

        let marks = repeatElement("?", count: names.count).joined(separator: ",")
        query += " AND name IN (\(marks))"
        arguments += names.map { $0.rawValue } as [DatabaseValueConvertible]

        if depth > 0 {
            query += " AND latitudeMin <= ? AND latitudeMax >= ? AND longitudeMin <= ? AND longitudeMax >= ?"
            arguments.append(coordinate.latitude)
            arguments.append(coordinate.latitude)
            arguments.append(coordinate.longitude)
            arguments.append(coordinate.longitude)
        }

        var models = store.userModels(for: query, arguments: StatementArguments(arguments))

        // create base models if missing
        for missingType in models.missingBaseTypes {
            if let model = UserActivityType(name: missingType, coordinate: coordinate) {
                logger.info("NEW MODEL: [\(model.geoKey)]")
                model.needsUpdate = true
                model.save()
                models.append(model)
            }
        }

        return models
    }

    func updateModelsContaining(_ segment: ItemSegment) {
        guard let activityType = segment.activityType else { return }

        var lastModel: UserActivityType?
        var models: Set<UserActivityType> = []

        for sample in segment.samples {
            guard let coordinate = sample.location?.coordinate else { continue }

            if let lastModel = lastModel, lastModel.contains(coordinate: coordinate) {
                continue
            }

            if let model = modelFor(name: activityType, coordinate: coordinate, depth: 2) {
                models.insert(model)
                lastModel = model
            }
        }

        for model in models {
            model.needsUpdate = true
            model.save()
        }
    }

    func updateModelsContaining(_ timelineItem: ArcTimelineItem, activityType: ActivityTypeName? = nil) {
        var modelType = activityType
        var lastModel: UserActivityType?
        var models: Set<UserActivityType> = []
        
        for sample in timelineItem.samples {
            if modelType == nil {
                if let confirmedType = sample.confirmedType {
                    modelType = confirmedType
                }
            }
            
            guard let modelType = modelType else { continue }
            
            guard sample.hasUsableCoordinate, let coordinate = sample.location?.coordinate else { continue }
            
            if let lastModel = lastModel, lastModel.name == modelType && lastModel.contains(coordinate: coordinate) {
                continue
            }
            
            if let model = modelFor(name: modelType, coordinate: coordinate, depth: 2) {
                models.insert(model)
                lastModel = model
            }
        }
        
        for model in models {
            model.needsUpdate = true
            model.save()
        }
    }
    
    func housekeep() {
        background {
            let nameMarks = repeatElement("?", count: ActivityTypeName.extendedTypes.count).joined(separator: ",")

            // mark empty user models for update (which will trigger a delete if still empty after update)
            let emptyUserModels = self.store.userModels(
                where: "totalSamples = 0 AND isShared = 0 AND name IN (\(nameMarks))",
                arguments: StatementArguments(ActivityTypeName.extendedTypes.map { $0.rawValue }))
            for model in emptyUserModels {
                model.needsUpdate = true
                model.save()
            }

            // rebuild anything non empty and older than current ActivityType version
            let oldModels = self.store.userModels(where: "version < ? AND isShared = 0 AND totalSamples > 0", arguments: [ActivityType.currentVersion])
            for model in oldModels {
                model.needsUpdate = true
                model.save()
            }
        }
    }

    var backgroundTaskExpired = false

    func updateQueuedModels(task: BGProcessingTask) {

        // handle background expiration
        if backgroundTaskExpired {
            TasksManager.update(.activityTypeModelUpdates, to: .expired)
            if !LocomotionManager.highlander.recordingState.isCurrentRecorder {
                store.disconnectFromDatabase()
            }
            task.setTaskCompleted(success: false)
            TasksManager.highlander.scheduleBackgroundTasks()
            return
        }

        // catch background expiration
        if task.expirationHandler == nil {
            backgroundTaskExpired = false
            task.expirationHandler = {
                self.backgroundTaskExpired = true
            }
        }

        // do the job
        store.connectToDatabase()
        if let model = store.userModel(where: "isShared = 0 AND needsUpdate = 1") {
            model.update(task: task) // this will recurse back to here on completion
            return
        }

        // job's finished
        TasksManager.update(.activityTypeModelUpdates, to: .completed)
        if !LocomotionManager.highlander.recordingState.isCurrentRecorder {
            store.disconnectFromDatabase()
        }
        task.setTaskCompleted(success: true)
    }

}
