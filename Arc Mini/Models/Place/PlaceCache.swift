//
//  PlaceCache.swift
//  LearnerCoacher
//
//  Created by Matt Greenfield on 14/10/17.
//  Copyright © 2017 Big Paua. All rights reserved.
//

import GRDB
import LocoKit
import LocoKitCore
import PromiseKit
import CoreLocation
import BackgroundTasks

class PlaceCache {

    static let maxRangeNoQuery: CLLocationDistance = 500
    static let maxRangeWithQuery: CLLocationDistance = 5000

    static var cache = PlaceCache()

    var store: ArcStore { return AppDelegate.store }

    lazy var updatesQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "ArcApp.PlaceCache.updatesQueue"
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .background
        return queue
    }()

    // MARK: - Cache lookups

    func placeFor(foursquareVenueId: String) -> Place? {
        return store.place(where: "foursquareVenueId = ?", arguments: [foursquareVenueId])
    }

    func placeFor(facebookPlaceId: String) -> Place? {
        return store.place(where: "facebookPlaceId = ?", arguments: [facebookPlaceId])
    }

    func placeFor(movesPlaceId: Int) -> Place? {
        return store.place(where: "movesPlaceId = ?", arguments: [movesPlaceId])
    }

    func placesNear(_ coordinate: CLLocationCoordinate2D, padding: CLLocationDegrees = 0.02) -> [Place] {
        let query = "latitude > :latMin AND latitude < :latMax AND longitude > :longMin AND longitude < :longMax"

        return store.places(where: query, arguments: [
            "latMin": coordinate.latitude - padding, "latMax": coordinate.latitude + padding,
            "longMin": coordinate.longitude - padding, "longMax": coordinate.longitude + padding
            ]
        )
    }

    func placesOverlapping(_ visit: ArcVisit) -> [Place] {
        guard let coordinate = visit.center?.coordinate else { return [] }
        return placesNear(coordinate).filter { $0.overlaps(visit) }
    }

    func placesOverlapping(_ segment: ItemSegment) -> [Place] {
        guard let coordinate = segment.center?.coordinate else { return [] }
        return placesNear(coordinate).filter { $0.overlaps(segment) }
    }

    func placesMatching(nameLike: String, near coordinate: CLLocationCoordinate2D? = nil) -> [Place] {

        // have search query to match against?
        if !nameLike.isEmpty { return store.places(where: "name LIKE ?", arguments: ["%\(nameLike)%"]) }

        // have coordinate to match against?
        if let coordinate = coordinate { return placesNear(coordinate) }

        return []
    }

    var haveHome: Bool {
        return store.place(where: "isHome = 1") != nil
    }

    // MARK: - Remote place fetching

    func fetchPlaces(for location: CLLocation, query: String = "") -> Promise<Void> {
        return fetchFoursquarePlaces(for: location, query: query)
    }

    private func fetchFoursquarePlaces(for location: CLLocation, query: String = "") -> Promise<Void> {
        return Promise { seal in
            background {
                Foursquare.fetchVenues(for: location, query: query).done { venues in
                    background {
                        guard let venues = venues else { seal.fulfill(()); return }
                        
                        var index = 0
                        for venue in venues {
                            if let place = PlaceCache.cache.placeFor(foursquareVenueId: venue.id) {
                                place.foursquareResultsIndex = index

                                // fill in missing category ids
                                if place.foursquareCategoryId == nil {
                                    place.foursquareCategoryId = venue.primaryCategory?.id
                                    place.save()
                                }

                                // update name if changed
                                if venue.name != place.name {
                                    print("UPDATING PLACE NAME: (old: \(place.name), new: \(venue.name))")
                                    place.name = venue.name
                                    place.save()
                                }

                            } else if let place = Place(foursquareVenue: venue) {
                                place.foursquareResultsIndex = index
                                place.save()
                            }

                            index += 1
                        }
                        
                        seal.fulfill(())
                    }

                }.catch { error in
                    seal.fulfill(())
                }
            }
        }
    }

    // MARK: - Misc

    func flushFoursquareResultsIndexes() {
        guard let enumerator = store.placeMap.objectEnumerator() else { return }
        while let place = enumerator.nextObject() as? Place {
            place.foursquareResultsIndex = nil
        }
    }

    // MARK: - Place updating

    var backgroundTaskExpired = false

    func updateQueuedPlaces(task: BGProcessingTask) {
        if backgroundTaskExpired {
            print("UPDATE QUEUED PLACES: BG TASK EXPIRED")
            task.setTaskCompleted(success: false)
            return
        }

        if task.expirationHandler == nil {
            // make sure the next round of tasks are scheduled
//            onMain { AppDelegate.delly.scheduleBackgroundTasks() }
            
            backgroundTaskExpired = false

            task.expirationHandler = {
                self.backgroundTaskExpired = true
            }
        }

        if let place = store.place(where: "needsUpdate = 1") {
            place.updateStatistics(task: task) // this will recurse back to here on completion
            return
        }

        print("UPDATE QUEUED PLACES: COMPLETED")
        task.setTaskCompleted(success: true)
    }

}

