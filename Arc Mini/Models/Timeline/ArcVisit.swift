//
//  ArcVisit.swift
//  LearnerCoacher
//
//  Created by Matt Greenfield on 13/12/17.
//  Copyright © 2017 Big Paua. All rights reserved.
//

import GRDB
import LocoKit
import SwiftNotes

class ArcVisit: LocoKit.Visit, ArcTimelineItem {

    static let titleDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    // MARK: - Init

    public required init(in store: TimelineStore) { super.init(in: store) }

    public required init(from dict: [String: Any?], in store: TimelineStore) {

        // ArcVisit
        if let uuidString = dict["placeId"] as? String {
            self.placeId = UUID(uuidString: uuidString)
        }
        self.manualPlace = dict["manualPlace"] as? Bool ?? false
        self.streetAddress = dict["streetAddress"] as? String
        self.customTitle = dict["customTitle"] as? String
        self.swarmCheckinId = dict["swarmCheckinId"] as? String

        // ArcTimelineItem
        self.activeEnergyBurned = dict["activeEnergyBurned"] as? Double
        self.averageHeartRate = dict["averageHeartRate"] as? Double
        self.maxHeartRate = dict["maxHeartRate"] as? Double
        if let steps = dict["hkStepCount"] as? Double {
            self.hkStepCount = Int(steps)
        }

        super.init(from: dict, in: store)
    }

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

            self.lastPlaceFind = Date()

            let results = PlaceClassifier(visit: self, overlappersOnly: true).results()

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

    // MARK: - Leaving probability

    var leavingProbabilityNow: Double? {
        return leavingProbability(at: Date())
    }

    func leavingProbability(at date: Date) -> Double? {
        return place?.leavingScoreFor(duration: self.duration + date.timeIntervalSinceNow, at: date)
    }

    var predictedLeavingTime: Date? {
        var testDate = Date()
        var peakDate: Date?
        var peakProbability = 0.0
        while true {
            guard let probability = leavingProbability(at: testDate) else { break }

            if probability >= 1 { break }

            // store the latest peak
            if probability > peakProbability {
                peakProbability = probability
                peakDate = testDate
            }

            testDate = testDate.addingTimeInterval(.oneMinute)
        }

        return peakDate
    }

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

    // MARK: - Persistable

    override func encode(to container: inout PersistenceContainer) {
        super.encode(to: &container)

        // ArcItem
        container["activeEnergyBurned"] = activeEnergyBurned
        container["averageHeartRate"] = averageHeartRate
        container["maxHeartRate"] = maxHeartRate
        container["hkStepCount"] = hkStepCount

        // ArcVisit
        container["streetAddress"] = streetAddress
        container["manualPlace"] = manualPlace
        container["customTitle"] = customTitle
        container["placeId"] = placeId?.uuidString
        container["swarmCheckinId"] = swarmCheckinId
    }

    // MARK: - Codable

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // ArcVisit
        self.streetAddress = try? container.decode(String.self, forKey: .streetAddress)
        self.manualPlace = try container.decode(Bool.self, forKey: .manualPlace)
        self.customTitle = try? container.decode(String.self, forKey: .customTitle)

        // ArcTimelineItem
        self.hkStepCount = try? container.decode(Int.self, forKey: .hkStepCount)
        self.activeEnergyBurned = try? container.decode(Double.self, forKey: .activeEnergyBurned)
        self.averageHeartRate = try? container.decode(Double.self, forKey: .averageHeartRate)
        self.maxHeartRate = try? container.decode(Double.self, forKey: .maxHeartRate)

        // PersistentVisit
        try super.init(from: decoder)
    }

    override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        // ArcItem
        if activeEnergyBurned != nil { try container.encode(activeEnergyBurned, forKey: .activeEnergyBurned) }
        if averageHeartRate != nil { try container.encode(averageHeartRate, forKey: .averageHeartRate) }
        if maxHeartRate != nil { try container.encode(maxHeartRate, forKey: .maxHeartRate) }
        if hkStepCount != nil { try container.encode(hkStepCount, forKey: .hkStepCount) }

        // ArcVisit
        if streetAddress != nil { try container.encode(streetAddress, forKey: .streetAddress) }
        if customTitle != nil { try container.encode(customTitle, forKey: .customTitle) }
        if placeId != nil {
            try container.encode(placeId, forKey: .placeId)
            try container.encode(manualPlace, forKey: .manualPlace)
            try container.encode(place, forKey: .place)
        }
        if swarmCheckinId != nil {
            try container.encode(swarmCheckinId, forKey: .swarmCheckinId)
        }

        if !notes.isEmpty { try container.encode(notes, forKey: .notes) }

        try super.encode(to: encoder)
    }

    enum CodingKeys: String, CodingKey {

        // ArcItem
        case notes
        case activeEnergyBurned
        case averageHeartRate
        case maxHeartRate
        case hkStepCount

        // ArcVisit
        case streetAddress
        case manualPlace
        case placeCKRecordName
        case customTitle
        case placeId
        case place
        case swarmCheckinId
    }
}

