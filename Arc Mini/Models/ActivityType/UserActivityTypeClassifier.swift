//
//  UserActivityTypeClassifier.swift
//  LearnerCoacher
//
//  Created by Matt Greenfield on 20/12/17.
//  Copyright © 2017 Big Paua. All rights reserved.
//

import LocoKit
import CoreLocation

final class UserActivityTypeClassifier: MLClassifier {
    typealias Cache = UserActivityTypesCache

    let depth: Int
    let models: [UserActivityType]

    lazy var lastUpdated: Date? = {
        return self.models.lastUpdated
    }()

    lazy var accuracyScore: Double? = {
        return self.models.accuracyScore
    }()

    lazy var completenessScore: Double = {
        return self.models.completenessScore
    }()

    var displayCoverageScore: Double {
        return coverageScore
    }

    var displayCoverageScoreString: String {
        return coverageScoreString
    }

    required init?(coordinate: CLLocationCoordinate2D, depth: Int) {
        self.depth = depth
        self.models = Cache.highlander.modelsFor(names: ActivityTypeName.allTypes, coordinate: coordinate, depth: depth)
    }
}
