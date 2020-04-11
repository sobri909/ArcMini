//
//  UserActivityType.swift
//  LearnerCoacher
//
//  Created by Matt Greenfield on 11/08/17.
//  Copyright © 2017 Big Paua. All rights reserved.
//

import Logging
import LocoKit
import CoreLocation
import BackgroundTasks

class UserActivityType: MutableActivityType {
    
    var updateTimer: Timer?

    init?(dict: [String: Any?]) {
        super.init(dict: dict, geoKeyPrefix: "U", in: RecordingManager.store)
    }

    convenience init?(name: ActivityTypeName, coordinate: CLLocationCoordinate2D) {
        if name == .unknown { return nil }
        
        let latitudeRange = ActivityType.latitudeRangeFor(depth: 2, coordinate: coordinate)
        let longitudeRange = ActivityType.longitudeRangeFor(depth: 2, coordinate: coordinate)
        
        var dict: [String: Any] = [:]
        dict["depth"] = 2
        dict["isShared"] = false
        dict["name"] = name.rawValue
        dict["latitudeMin"] = latitudeRange.min
        dict["latitudeMax"] = latitudeRange.max
        dict["longitudeMin"] = longitudeRange.min
        dict["longitudeMax"] = longitudeRange.max
        
        self.init(dict: dict)
    }

    // MARK: Updating

    func update(task: BGProcessingTask) {
        PlaceCache.cache.updatesQueue.addOperation {
            let done = {
                UserActivityTypesCache.highlander.updateQueuedModels(task: task)
            }

            guard self.shouldUpdate else {
                self.needsUpdate = false
                self.save()
                done()
                return
            }
            
            self.needsUpdate = false
            self.save()

            logger.info("[\(self.geoKey)] UPDATING")

            let dateBoundary = Date(timeIntervalSinceNow: -.oneYear * 2)

            // only update from the last X months of samples
            let samples = RecordingManager.store.samples(
                where: "confirmedType = ? AND latitude > ? AND latitude < ? AND longitude > ? AND longitude < ? "
                    + "AND date > ? AND source = ? ORDER BY date",
                arguments: [self.name.rawValue, self.latitudeRange.min, self.latitudeRange.max, self.longitudeRange.min,
                            self.longitudeRange.max, dateBoundary, "LocoKit"])

            // only reclassify the most recent samples, for accuracyScores
            let toClassify = samples.suffix(2000)

            for sample in toClassify where sample.classifierResults == nil {
                sample.classifierResults = RecordingManager.recorder.classifier?.classify(sample, previousResults: nil)
            }

            self.updateFrom(samples: samples)

            if let accuracy = self.accuracyScore {
                logger.info("UPDATED: \(self.geoKey) (samples: \(self.totalSamples) accuracy: \(String(format: "%.2f", accuracy))")
            } else {
                logger.info("UPDATED: \(self.geoKey) (samples: \(self.totalSamples))")
            }

            if self.totalSamples > 0 {
                self.save()

            } else if !ActivityTypeName.baseTypes.contains(self.name) { // empty and not base? delete it
                do {
                    try RecordingManager.store.auxiliaryPool.write { db in
                        try db.execute(sql: "DELETE FROM ActivityTypeModel WHERE geoKey = ?", arguments: [self.geoKey])
                    }
                    logger.info("DELETED: \(self.geoKey)")

                } catch {
                    logger.error("ERROR: \(error)")
                }
            }

            done()
        }
    }

    var shouldUpdate: Bool {
        if isShared { return false }

        // never updated?
        guard let lastUpdated = lastUpdated else { return true }

        // version is too old?
        if version < ActivityType.currentVersion { return true }

        // is empty?
        if totalSamples == 0 { return true }

        do {
            let query = "SELECT MAX(lastSaved) FROM LocomotionSample "
                + "WHERE confirmedType = ? AND latitude > ? AND latitude < ? AND longitude > ? AND longitude < ?"
            let lastSavedSample = try RecordingManager.store.pool.read { db in
                return try Date.fetchOne(db, sql: query, arguments: [name.rawValue, latitudeRange.min, latitudeRange.max,
                                                                     longitudeRange.min, longitudeRange.max])
            }
            if let lastSaved = lastSavedSample, lastSaved > lastUpdated { return true }

        } catch {
            logger.info("ERROR: \(error)")
            return false
        }

        return false
    }

}
