//
// Created by Matt Greenfield on 23/02/16.
// Copyright (c) 2016 Big Paua. All rights reserved.
//

import GRDB
import LocoKit
import CoreLocation

class Place: TimelineObject, Hashable, Encodable {

    // MARK: - Settings

    static let minimumPlaceRadius: Double = 8
    static let minimumNewPlaceRadius: Double = 60

    // MARK: - Properties

    let placeId: UUID
    var name: String = "" { didSet { hasChanges = true } }
    var needsUpdate: Bool = false { didSet { hasChanges = true } }
    var lastUpdated: Date?

    var center: CLLocation { didSet { hasChanges = true } }
    var radius: Radius = Radius.zero { didSet { hasChanges = true } }

    var foursquareVenueId: String? { didSet { hasChanges = true } }
    var foursquareCategoryId: String? { didSet { hasChanges = true } }
    var foursquareResultsIndex: Int? { didSet { hasChanges = true } }
    var facebookPlaceId: String? { didSet { hasChanges = true } }
    var movesPlaceId: Int? { didSet { hasChanges = true } }
    var isHome = false { didSet { hasChanges = true } }

    // stats
    var visitsCount = 0 { didSet { hasChanges = true } }
    var visitDays = 0 { didSet { hasChanges = true } }
    var averageSteps: Int? { didSet { hasChanges = true } }
    var averageCalories: Double? { didSet { hasChanges = true } }
    var averageHeartRate: Double? { didSet { hasChanges = true } }
    var averageMaxHeartRate: Double? { didSet { hasChanges = true } }
    
    // Bayes stuff
    var durations: ArcHistogram? { didSet { hasChanges = true } }
    var coordinatesMatrix: ArcCoordinatesMatrix? { didSet { hasChanges = true } }
    var visitTimes: [Weekday: ArcHistogram]? { didSet { hasChanges = true } }
    var startTimes: ArcHistogram? { didSet { hasChanges = true } }
    var endTimes: ArcHistogram? { didSet { hasChanges = true } }

    // MARK: - TimelineObject

    var transactionDate: Date?
    var hasChanges: Bool = false
    var lastSaved: Date?

    func save(immediate: Bool = true) {
        do {
            try RecordingManager.store.arcPool.write { db in
                self.transactionDate = Date()
                try self.save(in: db)
                self.lastSaved = self.transactionDate
            }
        } catch {
            print("ERROR: \(error)")
        }
    }

    func saveNoDate() {
        hasChanges = true
        do {
            try RecordingManager.store.arcPool.write { db in
                try self.save(in: db)
            }
        } catch {
            print("ERROR: \(error)")
        }
    }

    var source = "ArcMini"
    var objectId: UUID { return placeId }
    var store: TimelineStore? { return RecordingManager.store }

    // MARK: - PersistableRecord

    public static let databaseTableName = "Place"

    public static var persistenceConflictPolicy: PersistenceConflictPolicy {
        return PersistenceConflictPolicy(insert: .replace, update: .abort)
    }

    open func encode(to container: inout PersistenceContainer) {
        container["placeId"] = placeId.uuidString
        container["lastSaved"] = transactionDate ?? lastSaved ?? Date()
        container["needsUpdate"] = needsUpdate

        container["name"] = name
        container["latitude"] = center.coordinate.latitude
        container["longitude"] = center.coordinate.longitude
        container["radiusMean"] = radius.mean
        container["radiusSD"] = radius.sd

        container["foursquareVenueId"] = foursquareVenueId
        container["foursquareCategoryId"] = foursquareCategoryId
        container["facebookPlaceId"] = facebookPlaceId
        container["movesPlaceId"] = movesPlaceId
        container["isHome"] = isHome

        container["visitsCount"] = visitsCount
        container["visitDays"] = visitDays

        container["averageSteps"] = averageSteps
        container["averageCalories"] = averageCalories
        container["averageHeartRate"] = averageHeartRate
        container["averageMaxHeartRate"] = averageMaxHeartRate

        container["startTimesHistogram"] = startTimes?.serialised
        container["endTimesHistogram"] = endTimes?.serialised
        container["durationsHistogram"] = durations?.serialised
        container["coordinatesMatrix"] = coordinatesMatrix?.serialised

        if let visitTimes = visitTimes {
            var serialised: [String] = []
            for weekday in Weekday.allCases {
                if let histogram = visitTimes[weekday] {
                    serialised.append(histogram.serialised)
                } else {
                    serialised.append("")
                }
            }
            container["visitTimesHistograms"] = serialised.joined(separator: "|")
        }
    }

    // MARK: - Init

    init(name: String, center: CLLocation, radius: Radius) {
        self.placeId = UUID()
        self.radius = Radius(mean: max(radius.mean, Place.minimumPlaceRadius), sd: radius.sd)
        self.center = center
        self.name = name
        RecordingManager.store.add(self)
    }

    init(from dict: [String: Any?]) {
        if let uuidString = dict["placeId"] as? String {
            self.placeId = UUID(uuidString: uuidString)!
        } else {
            self.placeId = UUID()
        }

        self.lastSaved = dict["lastSaved"] as? Date

        if let needsUpdate = dict["needsUpdate"] as? Bool {
            self.needsUpdate = needsUpdate
        }

        if let name = dict["name"] as? String, !name.isEmpty {
            self.name = name
        } else {
            self.name = "Unnamed Place"
        }
        if let center = dict["center"] as? CLLocation {
            self.center = center
        } else if let latitude = dict["latitude"] as? Double, let longitude = dict["longitude"] as? Double {
            self.center = CLLocation(latitude: latitude, longitude: longitude)
        } else {
            fatalError("Invalid place center: \(String(describing: dict["center"]))")
        }
        if let mean = dict["radiusMean"] as? Double, let sd = dict["radiusSD"] as? Double {
            self.radius = Radius(mean: mean, sd: sd)
        }

        self.isHome = dict["isHome"] as? Bool ?? false
        self.foursquareVenueId = dict["foursquareVenueId"] as? String
        self.foursquareCategoryId = dict["foursquareCategoryId"] as? String
        self.facebookPlaceId = dict["facebookPlaceId"] as? String

        if let movesPlaceId = dict["movesPlaceId"] as? Int { self.movesPlaceId = movesPlaceId }
        else if let movesPlaceId = dict["movesPlaceId"] as? Int64 { self.movesPlaceId = Int(movesPlaceId) }

        if let count = dict["visitsCount"] as? Int64 { self.visitsCount = Int(count) }
        if let count = dict["visitDays"] as? Int64 { self.visitDays = Int(count) }

        if let steps = dict["averageSteps"] as? Int64 { self.averageSteps = Int(steps) }
        self.averageCalories = dict["averageCalories"] as? Double
        self.averageHeartRate = dict["averageHeartRate"] as? Double
        self.averageMaxHeartRate = dict["averageMaxHeartRate"] as? Double

        if let serialised = dict["startTimesHistogram"] as? String {
            self.startTimes = ArcHistogram(string: serialised)
            self.startTimes?.printModifier = 60 / 60 / 60 / 60
            self.startTimes?.printFormat = "%8.2f h"
            self.startTimes?.name = "Arrival Times"
            self.startTimes?.binName = "Arrival time"
            self.startTimes?.binValueName = "Visit"
            self.startTimes?.binValueNamePlural = "Visits"
        }
        if let serialised = dict["endTimesHistogram"] as? String {
            self.endTimes = ArcHistogram(string: serialised)
            self.endTimes?.printModifier = 60 / 60 / 60 / 60
            self.endTimes?.printFormat = "%8.2f h"
            self.endTimes?.name = "Leaving Times"
            self.endTimes?.binName = "Leaving time"
            self.endTimes?.binValueName = "Visit"
            self.endTimes?.binValueNamePlural = "Visits"
        }
        if let serialised = dict["durationsHistogram"] as? String {
            self.durations = ArcHistogram(string: serialised)
            self.durations?.printModifier = 60 / 60 / 60 / 60
            self.durations?.printFormat = "%8.2f h"
            self.durations?.name = "Visit Durations"
            self.durations?.binName = "Duration"
            self.durations?.binValueName = "Visit"
            self.durations?.binValueNamePlural = "Visits"
        }
        if let serialised = dict["coordinatesMatrix"] as? String {
            self.coordinatesMatrix = ArcCoordinatesMatrix(string: serialised)
        }
        if let visitTimesHistograms = dict["visitTimesHistograms"] as? String {
            let substrings = visitTimesHistograms.split(separator: "|", omittingEmptySubsequences: false)
            let strings = substrings.map { String($0) }
            setVisitTimesHistograms(from: strings)

        } else if let visitTimesStrings = dict["visitTimesHistograms"] as? [String] {
            setVisitTimesHistograms(from: visitTimesStrings)
        }

        RecordingManager.store.add(self)
    }

    func setVisitTimesHistograms(from visitTimesStrings: [String]) {
        guard visitTimesStrings.count == Weekday.allCases.count else {
            print("visitTimesStrings has wrong count: \(visitTimesStrings.count)")
            return
        }

        var histograms: [Weekday: ArcHistogram] = [:]
        for weekday in Weekday.allCases {
            let serialised = visitTimesStrings[weekday.rawValue]
            if !serialised.isEmpty, let histogram = ArcHistogram(string: serialised) {
                histograms[weekday] = histogram
            }
        }

        visitTimes = histograms
    }

    convenience init?(foursquareVenue venue: Foursquare.Venue) {
        var dict: [String: Any?] = [:]
        dict["name"] = venue.name
        dict["center"] = venue.location.clLocation
        dict["radiusMean"] = Place.minimumNewPlaceRadius
        dict["radiusSD"] = 0
        dict["foursquareVenueId"] = venue.id
        dict["foursquareCategoryId"] = venue.primaryCategory?.id
        self.init(from: dict)
    }

    // MARK: - Home place

    func markAsHome() {
        isHome = true
        save()
    }

    func unmarkAsHome() {
        isHome = false
        save()
    }

    // MARK: -

    var categoryIcon: UIImage {
        // have a proper icon?
        if let categoryId = foursquareCategoryId { return UIImage(foursquareCategoryId: categoryId) }

        // it's a home place?
        if isHome { return UIImage(named: "homeIcon")! }

        // it's a private place?
        if isPrivatePlace { return UIImage(named: "privatePlaceIcon")! }

        return UIImage(named: "defaultPlaceIcon24")!
    }

    var isPrivatePlace: Bool {
        return foursquareVenueId == nil && facebookPlaceId == nil
    }

    // MARK: - Misc

    var userCanEdit: Bool {
        let isFoursquare = foursquareVenueId != nil
        let isFacebook = facebookPlaceId != nil
        return !isFoursquare && !isFacebook
    }

    func overlaps(_ visit: ArcVisit) -> Bool {
        if let metresOfOverlap = metresOfOverlapWith(visit) {
            return metresOfOverlap >= 0
        }
        return false
    }

    func overlaps(_ segment: ItemSegment) -> Bool {
        if let metresOfOverlap = metresOfOverlapWith(segment) {
            return metresOfOverlap >= 0
        }
        return false
    }

    func metresOfOverlapWith(_ visit: ArcVisit) -> CLLocationDistance? {
        guard let visitCenter = visit.center else { return nil }

        // if very few visits, use a wider radius, to better cope with early visits to large places
        let sdBuffer: Double = visitsCount < 2 ? 4 : 3

        let combinedRadiuses = radius.mean + (radius.sd * sdBuffer) + visit.radius1sd
        let betweenCentres = center.distance(from: visitCenter)
        return -(betweenCentres - combinedRadiuses)
    }

    func metresOfOverlapWith(_ segment: ItemSegment) -> CLLocationDistance? {
        guard let segmentCenter = segment.center else { return nil }

        let combinedRadiuses = radius.with3sd + segment.radius.with2sd
        let betweenCentres = center.distance(from: segmentCenter)
        return -(betweenCentres - combinedRadiuses)
    }

    func edgeToEdgeDistanceFrom(_ visit: ArcVisit) -> CLLocationDistance? {
        if let overlap = metresOfOverlapWith(visit) {
            return -overlap
        }
        return nil
    }

    func edgeToEdgeDistanceFrom(_ segment: ItemSegment) -> CLLocationDistance? {
        if let overlap = metresOfOverlapWith(segment) {
            return -overlap
        }
        return nil
    }

    func contains(location otherLocation: CLLocation) -> Bool {
        let metresFromCentre = center.distance(from: otherLocation)
        return metresFromCentre <= radius.with3sd
    }

    var _lastVisit: DateInterval?
    var lastVisit: DateInterval? {
        if let cached = _lastVisit { return cached }
        guard let visit = RecordingManager.store.item(
            where: "placeId = ? AND deleted = 0 ORDER BY startDate DESC",
            arguments: [placeId.uuidString]) else { return nil }
        if !visit.isCurrentItem {
            _lastVisit = visit.dateRange 
        }
        return _lastVisit
    }
    
    // MARK: - MapItem

    var itemId: UUID { return placeId }
    var color: UIColor { return .orange }

    // MARK: - Encodable

    enum CodingKeys: String, CodingKey {
        case placeId
        case name
        case center
        case radius
        case foursquareVenueId
        case foursquareCategoryId
        case facebookPlaceId
        case isHome
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(placeId, forKey: .placeId)
        try container.encode(name, forKey: .name)
        try container.encode(center.coordinate, forKey: .center)
        try container.encode(radius, forKey: .radius)
        if foursquareVenueId != nil { try container.encode(foursquareVenueId, forKey: .foursquareVenueId) }
        if foursquareCategoryId != nil { try container.encode(foursquareCategoryId, forKey: .foursquareCategoryId) }
        if facebookPlaceId != nil { try container.encode(facebookPlaceId, forKey: .facebookPlaceId) }
        if isHome { try container.encode(isHome, forKey: .isHome) }
    }

    // MARK: - Hashable

    func hash(into hasher: inout Hasher) {
        hasher.combine(placeId)
    }

    static func ==(lhs: Place, rhs: Place) -> Bool {
        if lhs.placeId == rhs.placeId { return true }
        if let venueId = lhs.foursquareVenueId, !venueId.isEmpty, venueId == rhs.foursquareVenueId { return true }
        if let facebookId = lhs.facebookPlaceId, !facebookId.isEmpty, facebookId == rhs.facebookPlaceId { return true }
        if let movesPlaceId = lhs.movesPlaceId, movesPlaceId == rhs.movesPlaceId { return true }
        return false
    }

}
