//
//  ArcPath.swift
//  LearnerCoacher
//
//  Created by Matt Greenfield on 13/12/17.
//  Copyright © 2017 Big Paua. All rights reserved.
//

import LocoKit

class ArcPath: Path, ArcTimelineItem {

    // MARK: - ArcTimelineItem

    var title: String {
        if isDataGap { return "Data Gap" }
        return activityType?.displayName.capitalized ?? "Unknown"
    }

}
