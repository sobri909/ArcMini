//
//  Place.scores.swift
//  LearnerCoacher
//
//  Created by Matt Greenfield on 12/05/17.
//  Copyright © 2017 Big Paua. All rights reserved.
//

import LocoKit
import CoreLocation

extension Place {

    func arrivalScoreFor(_ visit: ArcVisit) -> Double {
        if visit.isCurrentItem {
            return arrivalScoreFor(center: visit.center, startDate: visit.startDate)
        } else { // not current visit? then take the visit duration into account
            return arrivalScoreFor(center: visit.center, startDate: visit.startDate, duration: visit.duration)
        }
    }

    func arrivalScoreFor(_ segment: ItemSegment) -> Double {
        return arrivalScoreFor(center: segment.center, startDate: segment.dateRange?.start)
    }

    private func arrivalScoreFor(center: CLLocation?, startDate: Date?, duration: TimeInterval? = nil) -> Double {
        var scores: [Double] = []

        scores.append(foursquareScore ?? 0.5)
        if let center = center {
            scores.append(latLongScoreFor(location: center))
            scores.append(distanceScoreFor(location: center))
        }
        if let sinceStartOfDay = startDate?.sinceStartOfDay {
            scores.append(lastVisitScoreFor(startTime: sinceStartOfDay) ?? 0.5)
            scores.append(scoreFor(startTime: sinceStartOfDay) ?? 0.5)
        }
        if let duration = duration {
            scores.append(scoreFor(duration: duration) ?? 0.5)
        }

        return scores.reduce(1.0, *).clamped(min: 0, max: 1)
    }

    func leavingScoreFor(duration: TimeInterval, at date: Date) -> Double? {
        guard visitsCount > 2 else { return nil }
        guard let binCount = endTimes?.binCount, binCount > 2 else { return nil }
        
        guard let durationScore = scoreFor(duration: duration) else { return nil }
        guard let endTimeScore = scoreFor(endTime: date.sinceStartOfDay) else { return nil }

        return endTimeScore * durationScore
    }
    
    func latLongScoreFor(location: CLLocation) -> Double {
        return coordinatesMatrix?.probabilityFor(location.coordinate) ?? 0.01
    }
    
    func distanceScoreFor(location: CLLocation) -> Double {
        let distance = center.distance(from: location)
        return (1.0 - (distance / 1000.0)).clamped(min: 0.01, max: 1.0)
    }

    func lastVisitScoreFor(startTime: TimeInterval) -> Double? {
        guard let lastVisitEndDate = lastVisitEndDate else { return nil }

        // visits past 365 days ago are too old
        let maxAgo: TimeInterval = 60 * 60 * 24 * 365

        let sinceLast = lastVisitEndDate.age
        let score = (1.0 - sinceLast / maxAgo)

        return score.clamped(min: 0.01, max: 1.0)
    }
    
    func scoreFor(startTime: TimeInterval) -> Double? {
        guard let binCount = startTimes?.binCount, binCount > 1 else {
            return nil
        }
        if let score = startTimes?.probabilityFor(startTime), score > 0 {
            return score
        }
        return nil
    }
    
    func scoreFor(endTime: TimeInterval) -> Double? {
        if let score = endTimes?.probabilityFor(endTime), score > 0 {
            return score
        }
        return nil
    }
    
    func scoreFor(duration: TimeInterval) -> Double? {
        if let score = durations?.probabilityFor(duration), score > 0 {
            return score
        }
        return nil
    }
    
    var foursquareScore: Double? {
        guard let foursquareIndex = foursquareResultsIndex else { return nil }
        let positionScore = 1.0 - (0.01 * Double(foursquareIndex))
        return positionScore.clamped(min: 0.01, max: 1.0)
    }
    
}
