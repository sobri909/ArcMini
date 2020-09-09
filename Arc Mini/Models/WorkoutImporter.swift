//
//  WorkoutImporter.swift
//  Arc
//
//  Created by Matt Greenfield on 25/12/18.
//  Copyright © 2018 Big Paua. All rights reserved.
//

import HealthKit
import Logging
import LocoKit
import LocoKitCore
import PromiseKit

class WorkoutImporter {

    // Import HealthKit Workout Routes
    static func fetchWorkouts(from fromDate: Date, to toDate: Date) {
//        guard AppDelegate.applicationState == .active else { return }

        // DEBUG: delete all HealthKit samples first
//        try! Stalker.store.pool.write { db in
//            try db.execute("DELETE FROM LocomotionSample WHERE source = ?", arguments: ["HealthKit"])
//        }

        let healthStore = Health.highlander.store
        var workouts: [HKWorkout]?
        var routes: [HKWorkoutRoute]?

        firstly {
            return healthStore.workouts(from: fromDate, to: toDate)

        }.then { (results: [HKWorkout]?) -> Promise<[HKWorkoutRoute]?> in
            workouts = results
            return healthStore.workoutRoutes(from: fromDate, to: toDate)

        }.done { (results: [HKWorkoutRoute]?) -> Void in
            routes = results

            guard let workouts = workouts else { return }
            guard let routes = routes else { return }

            for workout in workouts {
                guard let route = routes.first(where: { $0.dateRange == workout.dateRange }) else { continue }
                importWorkoutRoute(workout: workout, route: route)
            }

        }.catch { error in
            logger.error("\(error)")
        }
    }

    static func importWorkoutRoute(workout: HKWorkout, route: HKWorkoutRoute) {
        print("IMPORTING: workout: \(workout), route: \(route)")

        let query = HKWorkoutRouteQuery(route: route) { query, locations, done, error in
            if let error = error {
                logger.error("\(error)")
            }
            
            guard let locations = locations, !locations.isEmpty else { return }
            guard let range = locations.dateInterval else { return }
            guard let containingItem = containingItem(for: range) else { return }

            print("workout.range: \(range)")
            print("containingItem.range: \(containingItem.dateRange)")

            // TODO: if there's no iten at all, we should still import the workout

            // need only one item containing the range, and it needs to be either data gap or visit

            let brain = ActivityBrain.historicalLocationsBrain
            var samples: [PersistentSample] = []
            var lastSampleDate: Date?

            for location in locations {
                brain.add(rawLocation: location)

                // don't record too soon
                if let last = lastSampleDate, location.timestamp.timeIntervalSince(last) < 60.0 / 25 {
                    print("too soon for another sample (gap: \(location.timestamp.timeIntervalSince(last)))")
                    continue
                }

                brain.update()
                let sample = RecordingManager.store.createSample(from: brain.presentSample)
                // TODO: need to set manual type from the workout type
//                sample.confirmedType = activity.activityTypeName
                sample.source = "HealthKit"
                samples.append(sample)

                lastSampleDate = sample.date

                print("SAMPLE: \(sample)")

                // TODO: classify the sample with manual type of the workout type

//                Stalker.store.process {
//                    self.process(sample)
//                    self.updateSleepModeAcceptability()
//                }
            }
            print("SAMPLES: \(samples.count)")

            let workoutItem = RecordingManager.store.createPath(from: samples)
            workoutItem.store?.process {
                workoutItem.workoutRouteId = workout.uuid
                workoutItem.source = "HealthKit"
                workoutItem.save()
            }
        }

        Health.highlander.store.execute(query)
    }

    static func containingItem(for range: DateInterval) -> ArcTimelineItem? {
        guard let item = RecordingManager.store.item(
            where: "startDate <= :start AND endDate >= :end",
            arguments: [range.start, range.end]) as? ArcTimelineItem else { print("NO CONTAINING ITEM"); return nil }

        // must be a visit or a data gap
        guard item is ArcVisit || item.isDataGap else { print("NOT A VISIT OR DATA GAP"); return nil }

        return item
    }

}
