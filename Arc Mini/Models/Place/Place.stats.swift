//
//  Place.stats.swift
//  LearnerCoacher
//
//  Created by Matt Greenfield on 12/07/16.
//  Copyright © 2016 Big Paua. All rights reserved.
//

import LocoKit
import CloudKit
import PromiseKit
import BackgroundTasks

extension Place {

    func setNeedsUpdate() {
        if needsUpdate { return }
        needsUpdate = true
        save()
    }
    
    func updateStatistics(task: BGProcessingTask) {
        _lastVisit = nil

        PlaceCache.cache.updatesQueue.addOperation {
            let done = {
                PlaceCache.cache.updateQueuedPlaces(task: task)
            }
            
            let items = RecordingManager.store
                .items(where: "placeId = ? AND isVisit = 1 AND deleted = 0 ORDER BY startDate DESC", arguments: [self.placeId.uuidString])
                .filter { $0.dateRange != nil }
            
            guard let visits = items as? [ArcVisit] else {
                self.needsUpdate = false
                self.visitsCount = 0
                self.save()
                done()
                return
            }

            // last place update is more recent than last visit update? and visits count hasn't changed?
            if let lastUpdated = self.lastUpdated, let lastVisit = visits.first?.lastSaved, lastVisit < lastUpdated,
                visits.count == self.visitsCount
            {
                self.needsUpdate = false
                self.save()
                done()
                return
            }
            
            logger.info("UPDATING: \(self.name)")

            self.updateEndTimes(visits: visits)
            self.updateStartTimes(visits: visits)
            self.updateCoordinatesMatrix(visits: visits)
            self.updateVisitTimes(visits: visits)
            self.updateDurations(visits: visits)
            self.updateMiscStats(visits: visits)
            self.updateRTree()
            self.lastUpdated = Date()
            self.needsUpdate = false
            self.save()

            logger.info("UPDATED: \(self.name)")

            done()
        }
    }

    // MARK: - Misc stats
    
    func updateMiscStats(visits: [ArcVisit]) {

        // update visits count
        self.visitsCount = visits.count
        
        var totalDays = 0, completedVisits = 0, currentDay: Date?
        var totalDuration: TimeInterval = 0, durations: [TimeInterval] = []
        var calorieVisits = 0, totalCalories: Double = 0
        var averageHeartRateVisits = 0, totalAverageHeartRate: Double = 0
        var maxHeartRateVisits = 0, totalMaxHeartRate: Double = 0
        var totalStepsVisits = 0, totalSteps = 0
        var manualSamples: [LocomotionSample] = []
        var maxEndDate: Date?
        
        for visit in visits {
            guard let dateRange = visit.dateRange else { continue }
            
            // calc total unique visit days
            if let current = currentDay {
                if !dateRange.start.isSameDayAs(current) {
                    currentDay = visit.startDate
                    totalDays += 1
                }
            } else {
                currentDay = visit.startDate
                totalDays += 1
            }
            
            if let max = maxEndDate {
                if dateRange.end > max {
                    maxEndDate = dateRange.end
                }
            } else {
                maxEndDate = dateRange.end
            }
            
            if visit.manualPlace, manualSamples.count < 14400 { // 24 hours of samples is enough
                manualSamples.append(contentsOf: visit.samples)
            }

            // don't include the current visit in averages
            if visit.isCurrentItem {
                continue
            }

            completedVisits += 1
            
            // average duration
            totalDuration += visit.duration
            durations.append(visit.duration)

            // average steps
            if let stepCount = visit.stepCount, stepCount > 0 {
                totalStepsVisits += 1
                totalSteps += stepCount
            }
            
            // average calories
            if let activeEnergyBurned = visit.activeEnergyBurned, activeEnergyBurned > 0 {
                calorieVisits += 1
                totalCalories += activeEnergyBurned
            }
            
            // average heart rate
            if let averageHeartRate = visit.averageHeartRate, averageHeartRate > 0 {
                averageHeartRateVisits += 1
                totalAverageHeartRate += averageHeartRate
            }

            // average max heart rate
            if let maxHeartRate = visit.maxHeartRate, maxHeartRate > 0 {
                maxHeartRateVisits += 1
                totalMaxHeartRate += maxHeartRate
            }
        }
        
        self.visitDays = totalDays
        self.lastVisitEndDate = maxEndDate
        
        // location and radius
        if !manualSamples.isEmpty, let center = manualSamples.weightedCenter {
            self.center = center
            let radius = manualSamples.radius(from: center)
            self.radius = Radius(mean: max(radius.mean, Place.minimumPlaceRadius), sd: radius.sd)
        }

        // other averages
        if totalStepsVisits > 1 {
            self.averageSteps = totalSteps / totalStepsVisits
        }
        if calorieVisits > 1 {
            self.averageCalories = totalCalories / Double(calorieVisits)
        }
        if averageHeartRateVisits > 1 {
            self.averageHeartRate = totalAverageHeartRate / Double(averageHeartRateVisits)
        }
        if maxHeartRateVisits > 1 {
            self.averageMaxHeartRate = totalMaxHeartRate / Double(maxHeartRateVisits)
        }
    }
    
    func updateRTree() {
        let pool = RecordingManager.store.arcPool
        do {
            if let rtreeId = rtreeId {
                let rtree = PlaceRTree(id: rtreeId,
                                       latMin: center.coordinate.latitude, latMax: center.coordinate.latitude,
                                       lonMin: center.coordinate.longitude, lonMax: center.coordinate.longitude)
                try pool.write { try rtree.update($0) }
            } else {
                var rtree = PlaceRTree(latMin: center.coordinate.latitude, latMax: center.coordinate.latitude,
                                       lonMin: center.coordinate.longitude, lonMax: center.coordinate.longitude)
                try pool.write { try rtree.insert($0) }
                rtreeId = rtree.id
                saveNoDate()
            }
            
        } catch {
            logger.error(error, subsystem: .misc)
        }
    }

    // MARK: - Visit times histograms

    func updateVisitTimes(visits: [ArcVisit]) {

        // STEP 1: compile arrays of per minute, per weekday timestamps of "at the place"
        var all: [TimeInterval] = []
        var monday: [TimeInterval] = []
        var tuesday: [TimeInterval] = []
        var wednesday: [TimeInterval] = []
        var thursday: [TimeInterval] = []
        var friday: [TimeInterval] = []
        var saturday: [TimeInterval] = []
        var sunday: [TimeInterval] = []

        // collect timestamps from every visit
        for visit in visits {
            guard let visitDateRange = visit.dateRange else { continue }

            // starting values
            var workingDate = visitDateRange.start
            var workingWeekday = workingDate.weekday
            var workingStartOfDay = workingDate.startOfDay

            // performance helpers
            var absoluteTimestamp = visitDateRange.start.timeIntervalSince1970
            let endDateTimestamp = visitDateRange.end.timeIntervalSince1970

            // loop through all minutes in the visit
            while absoluteTimestamp < endDateTimestamp {
                var workingTimestamp = workingDate.timeIntervalSince(workingStartOfDay)

                // has the weekday changed?
                if workingTimestamp > 60 * 60 * 24 {
                    workingWeekday = workingDate.weekday
                    workingStartOfDay = workingDate.startOfDay
                    workingTimestamp = workingDate.timeIntervalSince(workingStartOfDay)
                }

                // store the minute
                all.append(workingTimestamp)
                switch workingWeekday {
                case .monday: monday.append(workingTimestamp)
                case .tuesday: tuesday.append(workingTimestamp)
                case .wednesday: wednesday.append(workingTimestamp)
                case .thursday: thursday.append(workingTimestamp)
                case .friday: friday.append(workingTimestamp)
                case .saturday: saturday.append(workingTimestamp)
                case .sunday: sunday.append(workingTimestamp)
                case .all: break
                }

                // prep the next iteration
                workingDate = workingDate.addingTimeInterval(60)
                absoluteTimestamp += 60
            }
        }

        // put them together in a walkable dict
        var allTimestamps: [Weekday: [TimeInterval]] = [:]
        allTimestamps[.all] = all
        allTimestamps[.monday] = monday
        allTimestamps[.tuesday] = tuesday
        allTimestamps[.wednesday] = wednesday
        allTimestamps[.thursday] = thursday
        allTimestamps[.friday] = friday
        allTimestamps[.saturday] = saturday
        allTimestamps[.sunday] = sunday

        // STEP 2: build a Histogram for each timestamps array
        var allHistograms: [Weekday: ArcHistogram] = [:]
        for (weekday, timestamps) in allTimestamps {
            let histogram = ArcHistogram(values: timestamps, maxBins: 48, minBoundary: 0, maxBoundary: 60 * 60 * 24,
                                         pseudoCount: 0, snapToBoundaries: true)
            allHistograms[weekday] = histogram
        }

        // STEP 3: we done
        visitTimes = allHistograms
    }

    // MARK: - Coords matrix

    func updateCoordinatesMatrix(visits: [ArcVisit]) {
        let manualVisits = visits.filter { $0.manualPlace == true }
        
        var samples: [PersistentSample] = []
        for visit in manualVisits {
            guard samples.count < 3600 else { break } // this is expensive, so 6 hours of samples is enough
            samples += visit.samples
        }
        
        coordinatesMatrix = ArcCoordinatesMatrix(samples: samples)
    }

    // MARK: - Misc histograms

    func updateStartTimes(visits: [ArcVisit]) {
        let startTimesOfDay = visits.compactMap { $0.startDate?.sinceStartOfDay }
        startTimes = ArcHistogram(values: startTimesOfDay, minBoundary: 0, maxBoundary: 60 * 60 * 24,
                               snapToBoundaries: true, name: "Arrival Times", printFormat: "%8.2f h",
                               printModifier: 60 / 60 / 60 / 60)
        startTimes?.binName = "Arrival time"
        startTimes?.binValueName = "Visit"
        startTimes?.binValueNamePlural = "Visits"
    }
    
    func updateEndTimes(visits: [ArcVisit]) {
        let endTimesOfDay = visits.compactMap { $0.endDate?.sinceStartOfDay }
        endTimes = ArcHistogram(values: endTimesOfDay, minBoundary: 0, maxBoundary: 60 * 60 * 24, snapToBoundaries: true,
                             name: "Leaving Times", printFormat: "%8.2f h", printModifier: 60 / 60 / 60 / 60)
        endTimes?.binName = "Leaving time"
        endTimes?.binValueName = "Visit"
        endTimes?.binValueNamePlural = "Visits"
    }

    func updateDurations(visits: [ArcVisit]) {
        let allDurations = visits.compactMap { $0.duration }
        durations = ArcHistogram(values: allDurations, minBoundary: 0, name: "Visit Durations", printFormat: "%8.2f h",
                              printModifier: 60 / 60 / 60 / 60)
        durations?.binName = "Duration"
        durations?.binValueName = "Visit"
        durations?.binValueNamePlural = "Visits"
    }

    // MARK: - Convenience getters

    var mostCommonDurations: [(from: TimeInterval, to: TimeInterval)]? {
        return durations?.peakRanges
    }
    
    var mostCommonStartTimes: [(from: TimeInterval, to: TimeInterval)]? {
        return startTimes?.peakRanges
    }
    
    var mostCommonEndTimes: [(from: TimeInterval, to: TimeInterval)]? {
        return endTimes?.peakRanges
    }
    
}
