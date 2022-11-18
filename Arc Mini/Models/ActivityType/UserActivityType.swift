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

final class UserActivityType: MutableActivityType {

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

            self.needsUpdate = false
            self.save()

            logger.info("UPDATING: \(self.geoKey)")

            // only include the last 2 years of samples
            let dateBoundary = Date(timeIntervalSinceNow: -.oneYear * 2)

            let rect = CoordinateRect(
                latitudeRange: self.latitudeRange.min...self.latitudeRange.max,
                longitudeRange: self.longitudeRange.min...self.longitudeRange.max
            )

            let start = Date()

            let samples = RecordingManager.store.samples(
                inside: rect,
                where: "confirmedType = ? AND date > ? ORDER BY date",
                arguments: [self.name.rawValue, dateBoundary]
            ).filter { $0.source == "LocoKit" }

            print("FETCHED samples: \(samples.count), duration: \(duration: start.age)")

            // only reclassify the most recent samples, for accuracyScores
            let toClassify = samples.suffix(2000)

            for sample in toClassify where sample.classifierResults == nil {
                sample.classifierResults = RecordingManager.recorder.classifier.classify(sample, previousResults: nil)
            }

            // update model using all confirmed samples since date boundary
            self.updateFrom(samples: samples)

            if let accuracy = self.accuracyScore {
                logger.info("UPDATED: \(self.geoKey) (samples: \(self.totalSamples) accuracy: \(String(format: "%.2f", accuracy)))")
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
                    logger.error("\(error)")
                }
            }

            done()
        }
    }

}
