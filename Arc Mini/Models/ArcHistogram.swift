//
//  ArcHistogram.swift
//  LearnerCoacher
//
//  Created by Matt Greenfield on 1/05/17.
//  Copyright © 2017 Big Paua. All rights reserved.
//

import LocoKit

typealias ItemsRangeFilter = ([TimelineItem], (min: Double, max: Double)) -> [TimelineItem]

class ArcHistogram: Histogram {
   
    var itemsRangeFilter: ItemsRangeFilter?

    func filtered(items: [TimelineItem], forBin bin: Int) -> [TimelineItem]? {
        guard let filter = itemsRangeFilter else { return nil }
        return filter(items, (min: bottomFor(bin: bin), max: topFor(bin: bin)))
    }

}
