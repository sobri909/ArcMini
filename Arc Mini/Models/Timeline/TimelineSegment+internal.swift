//
//  TimelineSegment+internal.swift
//  Arc
//
//  Created by Matt Greenfield on 14/2/19.
//  Copyright © 2019 Big Paua. All rights reserved.
//

import GRDB
import LocoKit

extension TimelineSegment {

    var itemsNeedingConfirm: [ArcTimelineItem] {
        return timelineItems.compactMap { $0 as? ArcTimelineItem }.filter { !$0.deleted && !$0.isMergeLocked && $0.needsConfirm }
    }
    
}
