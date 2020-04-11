//
//  UserActivityTypeClassifier.swift
//  LearnerCoacher
//
//  Created by Matt Greenfield on 20/12/17.
//  Copyright © 2017 Big Paua. All rights reserved.
//

import LocoKit
import CoreLocation

class UserActivityTypeClassifier: MLClassifier {

    typealias Cache = UserActivityTypesCache
    typealias ParentClassifier = Cache.ParentClassifier

    let depth: Int = 2
    let supportedTypes: [ActivityTypeName]
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
        if let parentScore = parent?.coverageScore, parentScore > coverageScore { return parentScore }
        return coverageScore
    }

    var displayCoverageScoreString: String {
        if let score = parent?.coverageScore, score > coverageScore, let string = parent?.coverageScoreString { return string }
        return coverageScoreString
    }

    required init?(requestedTypes: [ActivityTypeName], coordinate: CLLocationCoordinate2D) {
        self.supportedTypes = requestedTypes
        self.models = Cache.highlander.modelsFor(names: requestedTypes, coordinate: coordinate, depth: 2)

        // bootstrap the parent 
        _ = parent
    }

    private var _parent: ParentClassifier?
    public var parent: ParentClassifier? {
        if let parent = _parent {
            return parent
        }
        
        // no point in getting a parent if self is complete
        guard completenessScore < 1 else {
            return nil
        }
        
        // can't do anything without a coord
        guard let coordinate = centerCoordinate else {
            return nil
        }
        
        // try to fetch one
        _parent = ParentClassifier(requestedTypes: supportedTypes, coordinate: coordinate)
        
        return _parent
    }

}
