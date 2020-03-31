//
//  TimelineState.swift
//  Arc Mini
//
//  Created by Matt Greenfield on 31/3/20.
//  Copyright © 2020 Matt Greenfield. All rights reserved.
//

import LocoKit

class TimelineState: ObservableObject {
    @Published var timelineSegments: Array<TimelineSegment> = []
}
