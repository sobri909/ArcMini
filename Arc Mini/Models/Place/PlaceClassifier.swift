//
//  PlaceClassifier.swift
//  LearnerCoacher
//
//  Created by Matt Greenfield on 14/10/17.
//  Copyright © 2017 Big Paua. All rights reserved.
//

import Combine
import LocoKit
import CloudKit
import PromiseKit
import CoreLocation

class PlaceClassifier: ObservableObject {

    private static let updatesQueue = DispatchQueue(label: "placeClassifierUpdates", qos: .utility)

    var visit: ArcVisit?
    var segment: ItemSegment?
    var overlappersOnly = false

    @Published var query = ""
    @Published var debouncedQuery = ""
    @Published var results = [PlaceClassifierResultItem]()

    private var queryObserver: AnyCancellable?

    // MARK: -

    private init() {
        PlaceCache.cache.flushFoursquareResultsIndexes()
        queryObserver = $query
            .removeDuplicates()
            .debounce(for: 1, scheduler: PlaceClassifier.updatesQueue)
            .sink { newQuery in
                self.debouncedQuery = newQuery
                self.updateResults(includingRemote: true)
        }
    }

    convenience init(visit: ArcVisit, overlappersOnly: Bool = false) {
        self.init()
        self.visit = visit
        self.overlappersOnly = overlappersOnly
    }

    convenience init?(segment: ItemSegment, overlappersOnly: Bool = false) {
        if segment.center == nil { return nil }
        self.init()
        self.segment = segment
        self.overlappersOnly = overlappersOnly
    }

    // MARK: -

    var location: CLLocation? {
        if let center = segment?.center { return center }
        if let center = visit?.center { return center }
        return nil
    }

    // MARK - Results updating

    func updateResults(includingRemote: Bool = false) {
        if overlappersOnly && !query.isEmpty {
            logger.error("Cant use a query string on an overlappers only classifier.")
        }

        let places = fetchMatchingPlaces()

        var totalVisits = 0
        for place in places { totalVisits += place.visitsCount + 1 }

        var scores: [PlaceClassifierResultItem] = []
        for place in places {
            let arrivalScore: Double
            if let segment = segment {
                arrivalScore = place.arrivalScoreFor(segment)
            } else if let visit = visit {
                arrivalScore = place.arrivalScoreFor(visit)
            } else {
                fatalError("NO OBJECT TO CLASSIFY")
            }

            let pctOfAllVisits = Double(place.visitsCount + 1) / Double(totalVisits)
            let finalScore = arrivalScore * pctOfAllVisits

            scores.append(PlaceClassifierResultItem(place: place, score: finalScore))
        }

        self.results = scores.sorted { $0.score > $1.score }

        if includingRemote {
            fetchRemotePlaces().done {
                self.updateResults(includingRemote: false)
            }.cauterize()
        }
    }

    private func fetchMatchingPlaces() -> [Place] {
        guard let location = location else { return [] }

        if overlappersOnly {
            if let segment = segment {
                return PlaceCache.cache.placesOverlapping(segment)
            } else if let visit = visit {
                return PlaceCache.cache.placesOverlapping(visit)
            }
        }

        let maxRange = query.count > 1
            ? PlaceCache.maxRangeWithQuery
            : PlaceCache.maxRangeNoQuery

        let results = PlaceCache.cache.placesMatching(nameLike: query, near: location.coordinate).filter {
            $0.center.distance(from: location) < maxRange
        }
        
        var deduped: [Place] = []
        for place in results {
            if !deduped.contains(place) { deduped.append(place) }
        }
        return deduped
    }

    private func fetchRemotePlaces() -> Promise<Void> {
        guard let location = location else { return Promise { $0.fulfill(()) } }
        return PlaceCache.cache.fetchPlaces(for: location, query: query)
    }

}

struct PlaceClassifierResults: Sequence, IteratorProtocol {

    private let results: [PlaceClassifierResultItem]

    public init(results: [PlaceClassifierResultItem]) {
        self.results = results.sorted { $0.score > $1.score }
    }

    lazy var arrayIterator: IndexingIterator<Array<PlaceClassifierResultItem>> = {
        return self.results.makeIterator()
    }()

    var array: [PlaceClassifierResultItem] {
        return results
    }

    public var isEmpty: Bool {
        return count == 0
    }

    public var count: Int {
        return results.count
    }

    public var first: PlaceClassifierResultItem? {
        return self.results.first
    }

    public subscript(index: Int) -> PlaceClassifierResultItem {
        return results[index]
    }

    public subscript(place: Place) -> PlaceClassifierResultItem? {
        return results.first { $0.place == place }
    }

    mutating func next() -> PlaceClassifierResultItem? {
        return arrayIterator.next()
    }

}

struct PlaceClassifierResultItem: Equatable {

    let place: Place
    let score: Double

    static func ==(lhs: PlaceClassifierResultItem, rhs: PlaceClassifierResultItem) -> Bool {
        return lhs.place == rhs.place
    }

}
