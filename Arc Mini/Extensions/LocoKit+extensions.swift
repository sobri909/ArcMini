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
            UserActivityTypesCache.highlander.updateModelsContaining(self)
        }
    }
}

