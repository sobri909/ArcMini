//
//  LocoKit+extensions.swift
//  Arc Mini
//
//  Created by Matt Greenfield on 4/4/20.
//  Copyright © 2020 Matt Greenfield. All rights reserved.
//

import LocoKit

extension ActivityTypeName {
    var color: UIColor { return UIColor.color(for: self) }
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
//            UserActivityTypesCache.highlander.updateModelsContaining(self)
        }
    }
}

