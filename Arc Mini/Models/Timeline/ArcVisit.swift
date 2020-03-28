//
//  ArcVisit.swift
//  LearnerCoacher
//
//  Created by Matt Greenfield on 13/12/17.
//  Copyright © 2017 Big Paua. All rights reserved.
//

import LocoKit
import SwiftNotes

class ArcVisit: LocoKit.Visit, ArcTimelineItem {

    static let titleDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    // MARK: - Place

    var placeId: UUID? { didSet { hasChanges = true } }
    var manualPlace = false { didSet { hasChanges = true } }
    var hasPlace: Bool { return placeId != nil }
    var lastPlaceFind: Date?

    private var _place: Place?
    var place: Place? {
        guard let placeId = placeId else { return nil }
        if let cached = _place, cached.placeId == placeId { return cached }
        _place = arcStore?.place(for: placeId)
        return _place
    }

    private var _placeClassifier: PlaceClassifier?
    var placeClassifier: PlaceClassifier {
        if let cached = _placeClassifier, cached.location == self.center { return cached }
        _placeClassifier = PlaceClassifier(visit: self)
        return _placeClassifier!
    }

    func findAPlace() {
        // don't need a place if have a custom title
        guard self.customTitle == nil else { return }

        // too soon?
        if let lastPlaceFind = lastPlaceFind, lastPlaceFind.age < 60 * 5 { return }

        if isInvalid { return }
        if hasPlace { return }

        Jobs.addSecondaryJob("findAPlace.\(itemId.shortString)", dontDupe: true) {
            if self.isMergeLocked || self.deleted { return }
            if self.isInvalid { return }
            if self.hasPlace { return }

            // don't need a place if have a custom title
            guard self.customTitle == nil else { return }

            guard let classifier = PlaceClassifier(visit: self, overlappersOnly: true) else { return }

            self.lastPlaceFind = Date()

            let results = classifier.results()

            // got a result, and it's a previously used place? yay
            if let result = results.first, result.place.visitsCount > 0 {
                self.usePlace(result.place)
            }
        }
    }

    func usePlace(_ chosenPlace: Place, manualPlace manual: Bool = false) {
        let previousPlace = self.place

        store?.process {
            self.placeId = chosenPlace.placeId
            self.manualPlace = manual
            self.customTitle = nil
            self.save()

            onMain { trigger(.updatedTimelineItem, on: self) }

            // update place stats
            delay(2) {
                chosenPlace.setNeedsUpdate()
                if previousPlace != chosenPlace { previousPlace?.setNeedsUpdate() }
            }
        }

        // reprocess because a new merge might be possible
        TimelineProcessor.process(from: self)
    }

    func hasSamePlaceAs(_ otherVisit: ArcVisit) -> Bool {
        guard let placeId = placeId, let otherPlaceId = otherVisit.placeId else { return false }
        return placeId == otherPlaceId
    }

    // MARK: - Custom title
    
    var customTitle: String? {
        didSet {
            if let title = customTitle, !title.isEmpty {
                _place = nil
                placeId = nil
                manualPlace = false
            }
            hasChanges = true
        }
    }

    // MARK: - Street address

    var streetAddress: String? { didSet { hasChanges = true } }
    var fetchingStreetAddress = false
    var lastFetchedStreetAddress: Date?

    // MARK: - Swarm

    var swarmCheckinId: String? { didSet { hasChanges = true } }

    // MARK: - Health

    var activeEnergyBurned: Double? { didSet { hasChanges = true } }
    var averageHeartRate: Double? { didSet { hasChanges = true } }
    var maxHeartRate: Double? { didSet { hasChanges = true } }
    var hkStepCount: Int? { didSet { hasChanges = true } }
    var lastHealthKitLookup: Date?

    // MARK: - Last.fm

    var _trackPlays: [TrackPlay]?

    // MARK: - ArcTimelineItem

    var title: String {

        // have place with name
        if let place = place, place.name.count > 0 { return place.name }

        // have custom title
        if let customTitle = customTitle, customTitle.count > 1 { return customTitle }

        // have reverse geo
        if let address = streetAddress { return address }

        if isWorthKeeping { return "Unknown Place" }

        return "Brief Stop"
    }

    // MARK: - TimelineItem

    override func scoreForConsuming(item: TimelineItem) -> ConsumptionScore {
        guard let otherVisit = item as? ArcVisit else { return super.scoreForConsuming(item: item) }

        // same place
        if self.hasSamePlaceAs(otherVisit) {

            // if both have the same manual place state, favour the one with longer duration
            if self.manualPlace == otherVisit.manualPlace {
                return self.duration > otherVisit.duration ? .perfect : .high
            }

            // favour consumption by the visit with a manual place
            return self.manualPlace ? .perfect : .high

        } else if self.manualPlace && otherVisit.manualPlace { // different manual places
            return .impossible
        }

        // overlapping visits with different places
        if self.overlaps(otherVisit) {

            // different manual places
            if self.manualPlace && otherVisit.manualPlace {
                return .impossible
            }

            // manual consumer and not manual consumee
            if self.manualPlace && !otherVisit.manualPlace {
                return .high
            }

            // not manual consumer and manual consumee
            if !self.manualPlace && otherVisit.manualPlace {
                return .impossible
            }

            // not manual consumer and not manual consumee
            if !self.manualPlace && !otherVisit.manualPlace {
                return self.duration > otherVisit.duration ? .perfect : .high
            }
        }

        return super.scoreForConsuming(item: item)
    }

    override func willConsume(item: TimelineItem) {
        guard let otherVisit = item as? ArcVisit else { return }
        if self.swarmCheckinId == nil, otherVisit.swarmCheckinId != nil {
            self.swarmCheckinId = otherVisit.swarmCheckinId
        }
        if self.customTitle == nil, otherVisit.customTitle != nil {
            self.customTitle = otherVisit.customTitle
        }
    }

    
}

