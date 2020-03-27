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

    // place
    private var _place: Place?
    var place: Place? {
        guard let placeId = placeId else { return nil }
        if let cached = _place, cached.placeId == placeId { return cached }
        _place = arcStore?.place(for: placeId)
        return _place
    }
    var placeId: UUID? { didSet { hasChanges = true } }
    var manualPlace = false { didSet { hasChanges = true } }

    // swarm
    var swarmCheckinId: String? { didSet { hasChanges = true } }

    // health
    var activeEnergyBurned: Double? { didSet { hasChanges = true } }
    var averageHeartRate: Double? { didSet { hasChanges = true } }
    var maxHeartRate: Double? { didSet { hasChanges = true } }
    var hkStepCount: Int? { didSet { hasChanges = true } }
    var lastHealthKitLookup: Date?

    // last.fm
    var _trackPlays: [TrackPlay]?

    // MARK: - ArcTimelineItem

    var title: String {
        return "Visit"
    }
    
}

