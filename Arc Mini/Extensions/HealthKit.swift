//
//  HealthKit.swift
//
//  Created by Matt Greenfield on 2/7/18.
//  Copyright © 2018 Big Paua. All rights reserved.
//

import HealthKit
import CoreLocation
import PromiseKit

extension HKHealthStore {

    func save(_ object: HKObject) -> Promise<Bool> {
        return Promise { seal in
            self.save(object) { success, error in
                if let error = error {
                    seal.reject(error)
                    return
                }
                seal.fulfill(success)
            }
        }
    }

    func add(_ samples: [HKSample], to workout: HKWorkout) -> Promise<Bool> {
        return Promise { seal in
            if samples.isEmpty {
                seal.fulfill(true)
                return
            }
            self.add(samples, to: workout) { success, error in
                if let error = error {
                    seal.reject(error)
                    return
                }
                seal.fulfill(success)
            }
        }
    }

    func sampleQuery(sampleType: HKSampleType, predicate: NSPredicate?, limit: Int,
                     sortDescriptors: [NSSortDescriptor]?) -> Promise<[HKSample]> {
        return Promise { seal in
            let query = HKSampleQuery(sampleType: sampleType, predicate: predicate, limit: limit,
                                      sortDescriptors: sortDescriptors)
            { query, results, error in
                if let error = error {
                    seal.reject(error)
                    return
                }
                seal.fulfill(results ?? [])
            }

            self.execute(query)
        }
    }

    func workouts(from start: Date, to end: Date) -> Promise<[HKWorkout]?> {
        return Promise { seal in
            let pred = HKQuery.predicateForSamples(withStart: start, end: end)
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
            let query = HKSampleQuery(sampleType: Health.workoutType, predicate: pred, limit: 0, sortDescriptors: [sort])
            { query, workouts, error in
                if let error = error {
                    seal.reject(error)
                    return
                }
                seal.fulfill(workouts as? [HKWorkout])
            }
            self.execute(query)
        }
    }

    func workoutRoutes(from start: Date, to end: Date) -> Promise<[HKWorkoutRoute]?> {
        return Promise { seal in
            let pred = HKQuery.predicateForSamples(withStart: start, end: end)
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
            let query = HKSampleQuery(sampleType: Health.workoutRouteType, predicate: pred, limit: 0, sortDescriptors: [sort])
            { query, routes, error in
                if let error = error {
                    seal.reject(error)
                    return
                }
                seal.fulfill(routes as? [HKWorkoutRoute])
            }
            self.execute(query)
        }
    }

}

extension HKWorkoutRouteBuilder {

    func insertRouteData(_ routeData: [CLLocation]) -> Promise<Bool> {
        return Promise { seal in
            self.insertRouteData(routeData) { success, error in
                if let error = error {
                    seal.reject(error)
                    return
                }
                seal.fulfill(success)
            }
        }
    }

    func finishRoute(with workout: HKWorkout, metadata: [String : Any]?) -> Promise<HKWorkoutRoute?> {
        return Promise { seal in
            self.finishRoute(with: workout, metadata: metadata) { route, error in
                if let error = error {
                    seal.reject(error)
                    return
                }
                seal.fulfill(route)
            }
        }
    }

}

// MARK: -

extension HKSample {
    var dateRange: DateInterval {
        return DateInterval(start: startDate, end: endDate)
    }
}
