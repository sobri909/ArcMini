//
//  UserTimelineClassifier.swift
//  LearnerCoacher
//
//  Created by Matt Greenfield on 3/04/18.
//  Copyright © 2018 Big Paua. All rights reserved.
//

import LocoKit
import LocoKitCore

class UserTimelineClassifier: MLClassifierManager {

    typealias Classifier = UserActivityTypeClassifier

    static var highlander = UserTimelineClassifier()

    var sampleClassifier: Classifier?

    let mutex = PThreadMutex(type: .recursive)

}
