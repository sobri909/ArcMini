//
//  PlaceCache.swift
//  LearnerCoacher
//
//  Created by Matt Greenfield on 14/10/17.
//  Copyright © 2017 Big Paua. All rights reserved.
//

import GRDB
import LocoKit
import PromiseKit
import CoreLocation
import BackgroundTasks

class PlaceCache {

    static let maxRangeNoQuery: CLLocationDistance = 500
    static let maxRangeWithQuery: CLLocationDistance = 5000
    static let useFoursquareV3API = true

    static var cache = PlaceCache()

    var store: ArcStore { return RecordingManager.store }

    lazy var updatesQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "ArcApp.PlaceCache.updatesQueue"
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .background
        return queue
    }()

    // MARK: - Cache lookups

    func placeFor(foursquarePlaceId: String) -> Place? {
        return store.place(where: "foursquareVenueId = ?", arguments: [foursquarePlaceId])
    }

    func placeFor(facebookPlaceId: String) -> Place? {
        return store.place(where: "facebookPlaceId = ?", arguments: [facebookPlaceId])
    }

    func placeFor(movesPlaceId: Int) -> Place? {
        return store.place(where: "movesPlaceId = ?", arguments: [movesPlaceId])
    }

    func placesNear(_ coordinate: CLLocationCoordinate2D, padding: CLLocationDegrees = 0.02) -> [Place] {
        let query = """
            SELECT *
            FROM Place, PlaceRTree AS r
            WHERE
                rtreeId = r.id
                AND r.latMin >= :latMin AND r.latMax <= :latMax
                AND r.lonMin >= :longMin AND r.lonMax <= :longMax
        """

        return store.places(for: query, arguments: [
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
                if PlaceCache.useFoursquareV3API {
                    Foursquare.fetchPlaces(for: location, query: query).done { fsPlaces in
                        background {
                            guard let fsPlaces = fsPlaces else { seal.fulfill(()); return }

                            var index = 0
                            for fsPlace in fsPlaces {
                                if let place = PlaceCache.cache.placeFor(foursquarePlaceId: fsPlace.id) {
                                    place.foursquareResultsIndex = index

                                    // fill in missing category ids
                                    if place.foursquareCategoryIntId == nil {
                                        place.foursquareCategoryIntId = fsPlace.primaryCategory?.id
                                        place.save()
                                    }

                                    // update name if changed
                                    if fsPlace.name != place.name {
                                        logger.info("UPDATING PLACE NAME: (old: \(place.name), new: \(fsPlace.name))")
                                        place.name = fsPlace.name
                                        place.save()
                                    }

                                } else if let place = Place(foursquarePlace: fsPlace) {
                                    place.foursquareResultsIndex = index
                                    place.save()
                                    place.updateRTree()
                                }

                                index += 1
                            }

                            seal.fulfill(())
                        }

                    }.catch { error in
                        seal.fulfill(())
                    }

                } else { // Foursquare v2 API
                    Foursquare.fetchVenues(for: location, query: query).done { venues in
                        background {
                            guard let venues = venues else { seal.fulfill(()); return }

                            var index = 0
                            for venue in venues {
                                if let place = PlaceCache.cache.placeFor(foursquarePlaceId: venue.id) {
                                    place.foursquareResultsIndex = index

                                    // fill in missing category ids
                                    if place.foursquareCategoryId == nil {
                                        place.foursquareCategoryId = venue.primaryCategory?.id
                                        place.save()
                                    }

                                    // update name if changed
                                    if venue.name != place.name {
                                        logger.info("UPDATING PLACE NAME: (old: \(place.name), new: \(venue.name))")
                                        place.name = venue.name
                                        place.save()
                                    }

                                } else if let place = Place(foursquareVenue: venue) {
                                    place.foursquareResultsIndex = index
                                    place.save()
                                    place.updateRTree()
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

        // handle background expiration
        if backgroundTaskExpired {
            RecordingManager.safelyDisconnectFromDatabase()
            TasksManager.highlander.scheduleBackgroundTasks()
            return
        }

        // catch background expiration
        if task.expirationHandler == nil {
            backgroundTaskExpired = false
            task.expirationHandler = {
                self.backgroundTaskExpired = true
                TasksManager.update(.placeModelUpdates, to: .expired)
                task.setTaskCompleted(success: false)
            }
        }

        // do the job
        store.connectToDatabase()
        if let place = store.place(where: "needsUpdate = 1") {
            place.updateStatistics(task: task) // this will recurse back to here on completion
            return
        }

        // housekeep
        deleteUnusedPlaces()
        pruneRTreeRows()

        // job's finished
        TasksManager.update(.placeModelUpdates, to: .completed)
        RecordingManager.safelyDisconnectFromDatabase()
        task.setTaskCompleted(success: true)
    }

    func deleteUnusedPlaces() {
        let store = RecordingManager.store
        background {
            RecordingManager.store.connectToDatabase()

            let unusedPlaces = store.places(where: "visitsCount = 0 AND needsUpdate != 1")
            for place in unusedPlaces {
                let visitsCount = store.countItems(where: "placeId = ? AND deleted = 0 AND disabled = 0", arguments: [place.placeId.uuidString])
                guard visitsCount == 0 else { place.setNeedsUpdate(); continue }
                do {
                    logger.info("deleting: \(place.name)")
                    try store.arcPool.write { db in
                        try db.execute(sql: "DELETE FROM Place WHERE placeId = ?", arguments: [place.placeId.uuidString])
                    }
                } catch {
                    logger.error(error, subsystem: .misc)
                }
            }
        }
    }

    func pruneRTreeRows() {
        background {
            RecordingManager.store.connectToDatabase()
            do {
                try RecordingManager.store.arcPool.write {
                    try $0.execute(sql: "DELETE FROM PlaceRTree WHERE id NOT IN (SELECT rtreeId FROM Place WHERE rtreeId IS NOT NULL)")
                }
            } catch {
                logger.error(error, subsystem: .misc)
            }
        }
    }

}

