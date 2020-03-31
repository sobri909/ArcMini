//
//  PlaceClassifier.swift
//  LearnerCoacher
//
//  Created by Matt Greenfield on 14/10/17.
//  Copyright © 2017 Big Paua. All rights reserved.
//

import LocoKit
import CloudKit
import CoreLocation
import PromiseKit

class PlaceClassifier: ObservableObject {

    var visit: ArcVisit?
    var segment: ItemSegment?
    var overlappersOnly = false
    @Published var results = [PlaceClassifierResultItem]()

    init(visit: ArcVisit, overlappersOnly: Bool = false) {
        self.visit = visit
        self.overlappersOnly = overlappersOnly
        PlaceCache.cache.flushFoursquareResultsIndexes()
    }

    init?(segment: ItemSegment, overlappersOnly: Bool = false) {
        if segment.center == nil { return nil }
        self.segment = segment
        self.overlappersOnly = overlappersOnly
        PlaceCache.cache.flushFoursquareResultsIndexes()
    }

    var coordinate: CLLocationCoordinate2D? {
        if let visit = visit { return visit.center?.coordinate }
        if let segment = segment { return segment.center?.coordinate }
        return nil
    }

    // MARK - Results searching

    @discardableResult
    func results(query: String = "") -> PlaceClassifierResults {
        if overlappersOnly && !query.isEmpty {
            print("CANT USE A QUERY ON AN OVERLAPPERS ONLY CLASSIFIER!")
        }

        let places = placesFor(query: query)

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

        return PlaceClassifierResults(results: scores)
    }

    func fetchRemotePlaces(query: String = "") -> Promise<Void> {
        guard let location = location else { return Promise { $0.fulfill(()) } }
        return PlaceCache.cache.fetchPlaces(for: location, query: query)
    }

}

extension PlaceClassifier {

    var location: CLLocation? {
        if let center = segment?.center { return center }
        if let center = visit?.center { return center }
        return nil
    }

    private func placesFor(query: String = "") -> [Place] {
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

        let results = PlaceCache.cache.placesMatching(nameLike: query, near: coordinate).filter {
            $0.center.distance(from: location) < maxRange
        }
        
        var deduped: [Place] = []
        for place in results {
            if !deduped.contains(place) { deduped.append(place) }
        }
        return deduped
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
