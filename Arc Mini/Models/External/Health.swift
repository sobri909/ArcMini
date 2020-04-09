//
// Created by Matt Greenfield on 5/04/16.
// Copyright (c) 2016 Big Paua. All rights reserved.
//

import LocoKit
import HealthKit
import PromiseKit

class Health {

    static let highlander = Health()

    static var readPermissions: [HKQuantityType: Bool] = [:]

    // MARK: - Quantity type
    static let stepsType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
    static let activeEnergyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
    static let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
    static let bloodPressureSystolicType = HKQuantityType.quantityType(forIdentifier: .bloodPressureSystolic)!
    static let bloodPressureDiastolicType = HKQuantityType.quantityType(forIdentifier: .bloodPressureDiastolic)!
    static let distanceCycling = HKQuantityType.quantityType(forIdentifier: .distanceCycling)!
    static let distanceWalkingRunning = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!

    // MARK: - Object types
    static let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
    static let workoutType = HKObjectType.workoutType()

    // MARK: - Series types
    static let workoutRouteType = HKSeriesType.workoutRoute()
    
    static let requiredReadTypes = [stepsType]
    static let readTypes: Set<HKObjectType> = [stepsType, activeEnergyType, heartRateType, bloodPressureSystolicType,
                                               bloodPressureDiastolicType, workoutType, workoutRouteType, sleepType]
    static let writeTypes: Set<HKSampleType> = [workoutType, workoutRouteType, activeEnergyType, heartRateType,
                                                distanceCycling, distanceWalkingRunning]
    
    let store = HKHealthStore()

    func checkRequiredPermissions() {
//        guard AppDelegate.applicationState == .active else { return }
        for type in Health.requiredReadTypes {
            fetchReadPermission(for: type) { permission in
                onMain {
                    Health.readPermissions[type] = permission
                    if !permission {
                        logger.error("FFS. NO PERMISSION (\(type))")
                    }
                }
            }
        }
    }

    // MARK: - Perms fetching

    func requestPermissions(completion: (() -> Void)? = nil) {
//        guard AppDelegate.applicationState == .active else { completion?(); return }
        store.requestAuthorization(toShare: Health.writeTypes, read: Health.readTypes) { success, error in
            if let error = error {
                logger.error("requestPermissions ERROR: \(error)")
            }
            completion?()
        }
    }
    
    func fetchReadPermission(for quantityType: HKQuantityType, completion: @escaping (_ havePermission: Bool) -> Void) {
//        guard AppDelegate.applicationState == .active else { return }
        let query = HKSourceQuery(sampleType: quantityType, samplePredicate: nil) { query, sources, error in
            if let sources = sources, sources.count > 0 {
                completion(true)
            } else {
                completion(false)
            }
        }
        store.execute(query)
    }
    

    // MARK: - Data fetching

    func fetchSteps(from fromDate: Date, to toDate: Date, completion: @escaping (_ steps: Int?) -> Void) {
//        guard AppDelegate.applicationState == .active else { return }

        let pred = HKQuery.predicateForSamples(withStart: fromDate, end: toDate)
        
        let query = HKStatisticsQuery(quantityType: Health.stepsType, quantitySamplePredicate: pred,
                                      options: .cumulativeSum) { query, result, error in
            guard let quantity = result?.sumQuantity() else {
                completion(nil)
                return
            }

            let unit = HKUnit.count()
            completion(Int(quantity.doubleValue(for: unit)))
        }
        
        store.execute(query)
    }
    
    func fetchEnergy(from fromDate: Date, to toDate: Date, completion: @escaping (_ kcals: Double?) -> Void) {
//        guard AppDelegate.applicationState == .active else { return }

        let pred = HKQuery.predicateForSamples(withStart: fromDate, end: toDate)

        let query = HKStatisticsQuery(quantityType: Health.activeEnergyType, quantitySamplePredicate: pred,
                                      options: .cumulativeSum) { query, result, error in
            guard let quantity = result?.sumQuantity() else {
                completion(nil)
                return
            }

            let unit = HKUnit.kilocalorie()
            completion(quantity.doubleValue(for: unit))
        }

        store.execute(query)
    }

    func fetchAverageHeartRate(from fromDate: Date, to toDate: Date, completion: @escaping (_ averageHeartRate: Double?) -> Void) {
//        guard AppDelegate.applicationState == .active else { return }

        let pred = HKQuery.predicateForSamples(withStart: fromDate, end: toDate)

        let query = HKStatisticsQuery(quantityType: Health.heartRateType, quantitySamplePredicate: pred,
                                      options: .discreteAverage) { query, result, error in
            guard let quantity = result?.averageQuantity() else {
                completion(nil)
                return
            }

            let unit = HKUnit(from: "count/min")
            completion(quantity.doubleValue(for: unit))
        }

        store.execute(query)
    }

    func fetchMaxHeartRate(from fromDate: Date, to toDate: Date, completion: @escaping (_ maxHeartRate: Double?) -> Void) {
//        guard AppDelegate.applicationState == .active else { return }

        let pred = HKQuery.predicateForSamples(withStart: fromDate, end: toDate)

        let query = HKStatisticsQuery(quantityType: Health.heartRateType, quantitySamplePredicate: pred,
                                      options: .discreteMax) { query, result, error in
            guard let quantity = result?.maximumQuantity() else {
                completion(nil)
                return
            }

            let unit = HKUnit(from: "count/min")
            completion(quantity.doubleValue(for: unit))
        }

        store.execute(query)
    }

    struct BloodPressureRange {
        var systolicMin: Double
        var systolicMax: Double
        var diastolicMin: Double
        var diastolicMax: Double

        var displayString: String {
            var systolic: String
            var diastolic: String
            if systolicMin == systolicMax {
                systolic = String(format: "%.0f", systolicMin)
            } else {
                systolic = String(format: "%.0f-%.0f", systolicMin, systolicMax)
            }
            if diastolicMin == diastolicMax {
                diastolic = String(format: "%.0f", diastolicMin)
            } else {
                diastolic = String(format: "%.0f-%.0f", diastolicMin, diastolicMax)
            }
            return "\(systolic) / \(diastolic)"
        }
    }

    func fetchBloodPressureRange(from fromDate: Date, to toDate: Date, completion: @escaping (_ range: BloodPressureRange?) -> Void) {
//        guard AppDelegate.applicationState == .active else { return }

        var systolicMin: Double?
        var systolicMax: Double?
        var diastolicMin: Double?
        var diastolicMax: Double?

        let finish = {
            guard let systolicMin = systolicMin, let systolicMax = systolicMax else { return }
            guard let diastolicMin = diastolicMin, let diastolicMax = diastolicMax else { return }

            let range = BloodPressureRange(systolicMin: systolicMin, systolicMax: systolicMax,
                                           diastolicMin: diastolicMin, diastolicMax: diastolicMax)
            onMain { completion(range) }
        }

        let pred = HKQuery.predicateForSamples(withStart: fromDate, end: toDate)

        let query1 = HKSampleQuery(sampleType: Health.bloodPressureSystolicType, predicate: pred,
                                  limit: HKObjectQueryNoLimit, sortDescriptors: nil)
        { query, samples, error in
            if let error = error {
                if (error as? HKError)?.code == .errorDatabaseInaccessible {
                    logger.error("bloodPressureSystolicType HKError.errorDatabaseInaccessible")
                }
            }

            guard let samples = samples as? [HKQuantitySample], !samples.isEmpty else { completion(nil); return }

            let unit = HKUnit.millimeterOfMercury()
            var samplesMin: Double = Double.greatestFiniteMagnitude
            var samplesMax: Double = 0

            for sample in samples {
                let value = sample.quantity.doubleValue(for: unit)
                samplesMin = min(value, samplesMin)
                samplesMax = max(value, samplesMax)
            }

            systolicMin = samplesMin
            systolicMax = samplesMax

            finish()
        }

        let query2 = HKSampleQuery(sampleType: Health.bloodPressureDiastolicType, predicate: pred,
                                  limit: HKObjectQueryNoLimit, sortDescriptors: nil)
        { query, samples, error in
            if let error = error {
                if (error as? HKError)?.code == .errorDatabaseInaccessible {
                    logger.error("bloodPressureDiastolicType HKError.errorDatabaseInaccessible")
                }
            }

            guard let samples = samples as? [HKQuantitySample], !samples.isEmpty else { completion(nil); return }

            let unit = HKUnit.millimeterOfMercury()
            var samplesMin: Double = Double.greatestFiniteMagnitude
            var samplesMax: Double = 0

            for sample in samples {
                let value = sample.quantity.doubleValue(for: unit)
                samplesMin = min(value, samplesMin)
                samplesMax = max(value, samplesMax)
            }

            diastolicMin = samplesMin
            diastolicMax = samplesMax

            finish()
        }

        store.execute(query1)
        store.execute(query2)
    }
    
    func fetchHeartRateSamples(from fromDate: Date, to toDate: Date, completion: @escaping (_ samples: [HKQuantitySample]?) -> Void) {
//        guard AppDelegate.applicationState == .active else { return }

        let pred = HKQuery.predicateForSamples(withStart: fromDate, end: toDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        let query = HKSampleQuery(sampleType: Health.heartRateType, predicate: pred, limit: HKObjectQueryNoLimit,
                                  sortDescriptors: [sort])
        { query, samples, error in
            if let error = error {
                if (error as? HKError)?.code == .errorDatabaseInaccessible {
                    logger.error("fetchHeartRateSamples HKError.errorDatabaseInaccessible")
                }
            }

            guard let samples = samples as? [HKQuantitySample], !samples.isEmpty else { completion(nil); return }

            onMain { completion(samples) }
        }
        
        store.execute(query)
    }

    func fetchSleeps(from fromDate: Date, to toDate: Date, completion: @escaping (_ sleeps: [HKCategorySample]?) -> Void) {
//        guard AppDelegate.applicationState == .active else { return }

        let pred = HKQuery.predicateForSamples(withStart: fromDate, end: toDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        
        let query = HKSampleQuery(sampleType: Health.sleepType, predicate: pred, limit: 0,
                                  sortDescriptors: [sort]) { query, results, error in
            guard let results = results as? [HKCategorySample], !results.isEmpty else {
                return
            }
            
            onMain {
                completion(results)
            }
        }
        
        store.execute(query)
    }
}

// MARK: -

extension HKWorkout {
    
    var activityTypeName: String {
        switch workoutActivityType {
        case .americanFootball:
            return "American Football"
        case .archery:
            return "Archery"
        case .australianFootball:
            return "Australian Football"
        case .badminton:
            return "Badminton"
        case .baseball:
            return "Baseball"
        case .basketball:
            return "Basketball"
        case .bowling:
            return "Bowling"
        case .boxing: // See also HKWorkoutActivityTypeKickboxing.
            return "Boxing"
        case .climbing:
            return "Climbing"
        case .cricket:
            return "Cricket"
        case .crossTraining: // Any mix of cardio and/or strength training. See also HKWorkoutActivityTypeCoreTraining and HKWorkoutActivityTypeFlexibility.
            return "Cross Training"
        case .curling:
            return "Curling"
        case .cycling:
            return "Cycling"
        case .dance:
            return "Dance"
        case .danceInspiredTraining: // This remains available to access older data.
            return "Dance Inspired Training"
        case .elliptical:
            return "Elliptical"
        case .equestrianSports: // Polo, Horse Racing, Horse Riding, etc.
            return "EquestrianSports"
        case .fencing:
            return "Fencing"
        case .fishing:
            return "Fishing"
        case .functionalStrengthTraining: // Primarily free weights and/or body weight and/or accessories
            return "Functional Strength Training"
        case .golf:
            return "Golf"
        case .gymnastics:
            return "Gymnastics"
        case .handball:
            return "Handball"
        case .hiking:
            return "Hiking"
        case .hockey: // Ice Hockey, Field Hockey, etc.
            return "Hockey"
        case .hunting:
            return "Hunting"
        case .lacrosse:
            return "Lacrosse"
        case .martialArts:
            return "Martial Arts"
        case .mindAndBody: // Tai chi, meditation, etc.
            return "Mind and Body"
        case .mixedMetabolicCardioTraining: // Any mix of cardio-focused exercises
            return "Mixed Metabolic Cardio Training"
        case .paddleSports: // Canoeing, Kayaking, Outrigger, Stand Up Paddle Board, etc.
            return "Paddle Sports"
        case .play: // Dodge Ball, Hopscotch, Tetherball, Jungle Gym, etc.
            return "Play"
        case .preparationAndRecovery: // Foam rolling, stretching, etc.
            return "Preparation and Recovery"
        case .racquetball:
            return "Racquetball"
        case .rowing:
            return "Rowing"
        case .rugby:
            return "Rugby"
        case .running:
            return "Running"
        case .sailing:
            return "Sailing"
        case .skatingSports: // Ice Skating, Speed Skating, Inline Skating, Skateboarding, etc.
            return "Skating Sports"
        case .snowSports: // Sledding, Snowmobiling, Building a Snowman, etc.
            return "Snow Sports"
        case .soccer:
            return "Soccer"
        case .softball:
            return "Softball"
        case .squash:
            return "Squash"
        case .stairClimbing: // See also HKWorkoutActivityTypeStairs and HKWorkoutActivityTypeStepTraining.
            return "Stair Climbing"
        case .surfingSports: // Traditional Surfing, Kite Surfing, Wind Surfing, etc.
            return "SurfingSports"
        case .swimming:
            return "Swimming"
        case .tableTennis:
            return "Table Tennis"
        case .tennis:
            return "Tennis"
        case .trackAndField: // Shot Put, Javelin, Pole Vaulting, etc.
            return "Track and Field"
        case .traditionalStrengthTraining: // Primarily machines and/or free weights
            return "Strength Training"
        case .volleyball:
            return "Volleyball"
        case .walking:
            return "Walking"
        case .waterFitness:
            return "Water Fitness"
        case .waterPolo:
            return "Water Polo"
        case .waterSports: // Water Skiing, Wake Boarding, etc.
            return "Water Sports"
        case .wrestling:
            return "Wrestling"
        case .yoga:
            return "Yoga"
        case .snowboarding:
            return "Snowboarding"
        case .pilates:
            return "Pilates"
        case .taiChi:
            return "Tai Chi"
        case .jumpRope:
            return "Jump Rope"
        case .kickboxing:
            return "Kickboxing"
        case .downhillSkiing:
            return "Downhill Skiing"
        case .crossCountrySkiing:
            return "Cross Country Skiing"
        case .stairs:
            return "Stairs"
        case .stepTraining:
            return "Step Training"
        case .coreTraining:
            return "Core Training"
        case .mixedCardio:
            return "Mixed Cardio"
        case .wheelchairWalkPace:
            return "Wheelchair Walk Pace"
        case .wheelchairRunPace:
            return "Wheelchair Run Pace"
        case .handCycling:
            return "Hand Cycling"
        case .highIntensityIntervalTraining:
            return "HIIT"
        case .flexibility:
            return "Flexibility"
        case .barre:
            return "Barre"
        default:
            return "Workout"
        }
    }
}
