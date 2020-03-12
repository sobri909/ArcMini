//
//  ArcVisit.swift
//  LearnerCoacher
//
//  Created by Matt Greenfield on 13/12/17.
//  Copyright © 2017 Big Paua. All rights reserved.
//

import LocoKit

class ArcVisit: LocoKit.Visit, ArcTimelineItem {

    static let titleDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    // MARK: - ArcTimelineItem

    var title: String {
        return "Visit"
    }
    
}

