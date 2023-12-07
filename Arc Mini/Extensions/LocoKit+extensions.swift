//
//  LocoKit+extensions.swift
//  Arc Mini
//
//  Created by Matt Greenfield on 4/4/20.
//  Copyright © 2020 Matt Greenfield. All rights reserved.
//

import LocoKit
import HealthKit

extension ActivityTypeName {
    var color: UIColor { return UIColor.color(for: self) }
    
    static let canSaveToWorkouts = [
        walking, running, cycling, skateboarding, inlineSkating, skiing, snowboarding, horseback
    ]

    var workoutActivityType: HKWorkoutActivityType? {
        if self == .walking { return .walking }
        if self == .running { return .running }
        if self == .cycling { return .cycling }
        if self == .skateboarding { return .skatingSports }
        if self == .inlineSkating { return .skatingSports }
        if self == .skiing { return .downhillSkiing }
        if self == .snowboarding { return .snowboarding }
        if self == .horseback { return .equestrianSports }
        return nil
    }

    var hkQuantityType: HKQuantityType? {
        if self == .walking { return HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning) }
        if self == .running { return HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning) }
        if self == .cycling { return HKObjectType.quantityType(forIdentifier: .distanceCycling) }
        if self == .skiing { return HKObjectType.quantityType(forIdentifier: .distanceDownhillSnowSports) }
        if self == .snowboarding { return HKObjectType.quantityType(forIdentifier: .distanceDownhillSnowSports) }
        return nil
    }
}

extension ItemSegment {
    func trainActivityType(to confirmedType: ActivityTypeName) {
        var changed = false
        for sample in samples where sample.confirmedType != confirmedType {
            sample.confirmedType = confirmedType
            changed = true
        }
        if changed {
            (timelineItem as? ArcTimelineItem)?.samplesChanged()
            CoreMLModelUpdater.highlander.queueUpdatesForModelsContaining(self)
        }
    }
}

extension TimelineSegment {
    func filename(for rangeType: Calendar.Component) -> String? {
        switch rangeType {
        case .day: return dayFilename
        case .weekOfYear: return monthFilename
        case .month: return monthFilename
        case .year: return yearFilename
        default: return singleItemFilename
        }
    }

    func exportToJSON(filenameType: Calendar.Component) -> URL? {
        guard let filename = filename(for: filenameType) else { return nil }

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601

        do {
            let json = try encoder.encode(self)
            let jsonFile = NSURL.fileURL(withPath: NSTemporaryDirectory() + filename + ".json")
            try json.write(to: jsonFile)
            return jsonFile
            
        } catch {
            logger.error("\(error)")
        }

        return nil
    }
}

