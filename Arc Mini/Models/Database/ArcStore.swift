//
//  ArcStore.swift
//  Arc Mini
//
//  Created by Matt Greenfield on 12/3/20.
//  Copyright © 2020 Matt Greenfield. All rights reserved.
//

import Foundation
import GRDB
import LocoKit

final class ArcStore: TimelineStore {

    override var dbDir: URL { get { return arcDbDir } set {} }
    override var modelsDir: URL { get { return arcModelsDir } set {} }

    lazy var arcDbDir: URL = {
        if let groupDir = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.ArcApp") { return groupDir }
        return try! FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
    }()

    lazy var arcModelsDir: URL = {
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.ArcApp")!
            .appendingPathComponent("MLModels", isDirectory: true)
    }()

    lazy var arcDbUrl: URL = {
        return arcDbDir.appendingPathComponent("ArcApp.sqlite")
    }()

    public lazy var arcPool: DatabasePool = {
        return try! DatabasePool(path: self.arcDbUrl.path, configuration: self.poolConfig)
    }()

    let placeMap = NSMapTable<NSUUID, Place>.strongToWeakObjects()
    let noteMap = NSMapTable<NSUUID, Note>.strongToWeakObjects()
    let userModelMap = NSMapTable<NSString, UserActivityType>.strongToWeakObjects()
    let timelineSummaryMap = NSMapTable<NSUUID, TimelineRangeSummary>.strongToWeakObjects()

    var placesInStore: Int { return mutex.sync { placeMap.objectEnumerator()?.allObjects.count ?? 0 } }
    var notesInStore: Int { return mutex.sync { noteMap.objectEnumerator()?.allObjects.count ?? 0 } }
    var userModelsInStore: Int { return mutex.sync { userModelMap.objectEnumerator()?.allObjects.count ?? 0 } }
    var timelineSummariesInStore: Int { return mutex.sync { timelineSummaryMap.objectEnumerator()?.allObjects.count ?? 0 } }
    
    static var saveNoDateBatchSize = 50
    var itemsToSaveNoDate: Set<TimelineItem> = []
    var samplesToSaveNoDate: Set<ArcSample> = []

    // MARK: - Object creation

    override func createVisit(from sample: PersistentSample) -> ArcVisit {
        let visit = ArcVisit(in: self)
        visit.add(sample)
        return visit
    }

    override func createPath(from sample: PersistentSample) -> ArcPath {
        let path = ArcPath(in: self)
        path.add(sample)
        return path
    }

    override func createVisit(from samples: [PersistentSample]) -> ArcVisit {
        let visit = ArcVisit(in: self)
        visit.add(samples)
        return visit
    }

    override func createPath(from samples: [PersistentSample]) -> ArcPath {
        let path = ArcPath(in: self)
        path.add(samples)
        return path
    }

    override func item(for row: Row) -> TimelineItem {
        guard let itemId = row["itemId"] as String? else { fatalError("MISSING ITEMID") }
        if let item = object(for: UUID(uuidString: itemId)!) as? TimelineItem { return item }
        guard let isVisit = row["isVisit"] as Bool? else { fatalError("MISSING ISVISIT BOOL") }
        return isVisit ? ArcVisit(from: row.asDict(in: self), in: self) : ArcPath(from: row.asDict(in: self), in: self)
    }

    func noteInStore(matching: (Note) -> Bool) -> Note? {
        return mutex.sync {
            guard let enumerator = noteMap.objectEnumerator() else { return nil }
            for case let note as Note in enumerator {
                if matching(note) { return note }
            }
            return nil
        }
    }

    func placeInStore(matching: (Place) -> Bool) -> Place? {
        return mutex.sync {
            guard let enumerator = placeMap.objectEnumerator() else { return nil }
            for case let place as Place in enumerator {
                if matching(place) { return place }
            }
            return nil
        }
    }

    // MARK: - Places

    func place(for placeId: UUID) -> Place? {
        if let cached = mutex.sync(execute: { placeMap.object(forKey: placeId as NSUUID) }), !cached.invalidated { return cached }
        return place(where: "placeId = ?", arguments: [placeId.uuidString])
    }

    func place(where query: String, arguments: StatementArguments = StatementArguments()) -> Place? {
        return place(for: "SELECT * FROM Place WHERE " + query, arguments: arguments)
    }

    func place(for query: String, arguments: StatementArguments = StatementArguments()) -> Place? {
        return try! arcPool.read { db in
            guard let row = try Row.fetchOne(db, sql: query, arguments: arguments) else { return nil }
            return place(for: row)
        }
    }

    public func places(where query: String, arguments: StatementArguments = StatementArguments()) -> [Place] {
        return places(for: "SELECT * FROM Place WHERE " + query, arguments: arguments)
    }

    public func places(for query: String, arguments: StatementArguments = StatementArguments()) -> [Place] {
        return try! arcPool.read { db in
            var places: [Place] = []
            let rows = try Row.fetchCursor(db, sql: query, arguments: arguments)
            while let row = try rows.next() { places.append(place(for: row)) }
            return places
        }
    }

    func countPlaces(where query: String = "1", arguments: StatementArguments = StatementArguments()) -> Int {
        return try! arcPool.read { db in
            return try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM Place WHERE " + query, arguments: arguments)!
        }
    }

    func place(for row: Row) -> Place {
        guard let placeId = row["placeId"] as String? else { fatalError("MISSING PLACEID") }
        if let cached = mutex.sync(execute: { placeMap.object(forKey: UUID(uuidString: placeId)! as NSUUID) }), !cached.invalidated {
            return cached
        }
        return Place(from: row.asDict(in: self))
    }

    func add(_ place: Place) {
        mutex.sync { placeMap.setObject(place, forKey: place.placeId as NSUUID) }
    }

    // MARK: - Notes

    func note(for noteId: UUID) -> Note? {
        if let cached = mutex.sync(execute: { noteMap.object(forKey: noteId as NSUUID) }), !cached.invalidated { return cached }
        return note(where: "noteId = ?", arguments: [noteId.uuidString])
    }

    func note(where query: String, arguments: StatementArguments = StatementArguments()) -> Note? {
        return note(for: "SELECT * FROM Note WHERE " + query, arguments: arguments)
    }

    func note(for query: String, arguments: StatementArguments = StatementArguments()) -> Note? {
        guard let pool = pool else { fatalError("Attempting to access the database when disconnected") }
        return try! pool.read { db in
            guard let row = try Row.fetchOne(db, sql: query, arguments: arguments) else { return nil }
            return note(for: row)
        }
    }

    public func notes(where query: String, arguments: StatementArguments = StatementArguments()) -> [Note] {
        return notes(for: "SELECT * FROM Note WHERE " + query, arguments: arguments)
    }

    public func notes(for query: String, arguments: StatementArguments = StatementArguments()) -> [Note] {
        guard let pool = pool else { fatalError("Attempting to access the database when disconnected") }
        return try! pool.read { db in
            var notes: [Note] = []
            let rows = try Row.fetchCursor(db, sql: query, arguments: arguments)
            while let row = try rows.next() { notes.append(note(for: row)) }
            return notes
        }
    }

    func countNotes(where query: String = "1", arguments: StatementArguments = StatementArguments()) -> Int {
        guard let pool = pool else { fatalError("Attempting to access the database when disconnected") }
        return try! pool.read { db in
            return try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM Note WHERE " + query, arguments: arguments)!
        }
    }

    func note(for row: Row) -> Note {
        guard let noteId = row["noteId"] as String? else { fatalError("MISSING NOTEID") }
        if let cached = mutex.sync(execute: { noteMap.object(forKey: UUID(uuidString: noteId)! as NSUUID) }), !cached.invalidated {
            return cached
        }
        return Note(from: row.asDict(in: self))
    }

    func add(_ note: Note) {
        mutex.sync { noteMap.setObject(note, forKey: note.noteId as NSUUID) }
    }

    // MARK: - Models

    public func userModel(where query: String, arguments: StatementArguments = StatementArguments()) -> UserActivityType? {
        return userModel(for: "SELECT * FROM ActivityTypeModel WHERE " + query, arguments: arguments)
    }

    public func userModel(for query: String, arguments: StatementArguments = StatementArguments()) -> UserActivityType? {
        return try! auxiliaryPool.read { db in
            guard let row = try Row.fetchOne(db, sql: query, arguments: arguments) else { return nil }
            return userModel(for: row)
        }
    }

    public func userModels(where query: String, arguments: StatementArguments = StatementArguments()) -> [UserActivityType] {
        return userModels(for: "SELECT * FROM ActivityTypeModel WHERE " + query, arguments: arguments)
    }

    public func userModels(for query: String, arguments: StatementArguments = StatementArguments()) -> [UserActivityType] {
        let rows = try! auxiliaryPool.read { db in
            return try Row.fetchAll(db, sql: query, arguments: arguments)
        }
        return rows.map { userModel(for: $0) }
    }

    func userModel(for row: Row) -> UserActivityType {
        guard let geoKey = row["geoKey"] as String? else { fatalError("MISSING GEOKEY") }
        if let cached = mutex.sync(execute: { userModelMap.object(forKey: geoKey as NSString) }) { return cached }
        if let model = UserActivityType(dict: row.asDict(in: self)) { return model }
        fatalError("FAILED MODEL INIT FROM ROW")
    }

    override func add(_ model: ActivityType) {
        if let model = model as? UserActivityType {
            mutex.sync { userModelMap.setObject(model, forKey: model.geoKey as NSString) }
        } else {
            super.add(model)
        }
    }

    // MARK: - Timeline Summaries

    func timelineSummary(for summaryId: UUID) -> TimelineRangeSummary? {
        if let cached = mutex.sync(execute: { timelineSummaryMap.object(forKey: summaryId as NSUUID) }), !cached.invalidated { return cached }
        return timelineSummary(where: "summaryId = ?", arguments: [summaryId.uuidString])
    }

    func timelineSummary(for dateRange: DateInterval) -> TimelineRangeSummary? {
        return timelineSummary(where: "startDate = :start AND endDate = :end", arguments: ["start": dateRange.start, "end": dateRange.end])
    }

    func timelineSummary(where query: String, arguments: StatementArguments = StatementArguments()) -> TimelineRangeSummary? {
        return timelineSummary(for: "SELECT * FROM TimelineRangeSummary WHERE " + query, arguments: arguments)
    }

    func timelineSummary(for query: String, arguments: StatementArguments = StatementArguments()) -> TimelineRangeSummary? {
        return try! arcPool.read { db in
            guard let row = try Row.fetchOne(db, sql: query, arguments: arguments) else { return nil }
            return timelineSummary(for: row)
        }
    }

    public func timelineSummaries(where query: String, arguments: StatementArguments = StatementArguments()) -> [TimelineRangeSummary] {
        return timelineSummaries(for: "SELECT * FROM TimelineRangeSummary WHERE " + query, arguments: arguments)
    }

    public func timelineSummaries(for query: String, arguments: StatementArguments = StatementArguments()) -> [TimelineRangeSummary] {
        return try! arcPool.read { db in
            var summaries: [TimelineRangeSummary] = []
            let rows = try Row.fetchCursor(db, sql: query, arguments: arguments)
            while let row = try rows.next() { summaries.append(timelineSummary(for: row)) }
            return summaries
        }
    }

    func countTimelineSummaries(where query: String = "1", arguments: StatementArguments = StatementArguments()) -> Int {
        return try! arcPool.read { db in
            return try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM TimelineRangeSummary WHERE " + query, arguments: arguments)!
        }
    }

    func timelineSummary(for row: Row) -> TimelineRangeSummary {
        guard let summaryId = row["summaryId"] as String? else { fatalError("MISSING SUMMARYID") }
        if let cached = mutex.sync(execute: { timelineSummaryMap.object(forKey: UUID(uuidString: summaryId)! as NSUUID) }), !cached.invalidated {
            return cached
        }
        return TimelineRangeSummary(from: row.asDict(in: self))
    }

    func add(_ summary: TimelineRangeSummary) {
        mutex.sync { timelineSummaryMap.setObject(summary, forKey: summary.summaryId as NSUUID) }
    }

    // MARK: - Saving for backups
    // These save methods don't update the lastSaved date
    
    public func saveNoDate(_ object: TimelineObject) {
        mutex.sync {
            if let item = object as? TimelineItem {
                itemsToSaveNoDate.insert(item)
            } else if let sample = object as? ArcSample {
                samplesToSaveNoDate.insert(sample)
            }
        }
        if itemsToSaveNoDate.count + samplesToSaveNoDate.count >= ArcStore.saveNoDateBatchSize { saveNoDate() }
    }

    func saveNoDate() {
        RecordingManager.store.connectToDatabase()
        guard let pool = pool else { fatalError("Attempting to access the database when disconnected") }

        var savingItems: Set<TimelineItem> = []
        var savingSamples: Set<ArcSample> = []

        mutex.sync {
            savingItems = itemsToSaveNoDate
            itemsToSaveNoDate.removeAll(keepingCapacity: true)

            savingSamples = samplesToSaveNoDate
            samplesToSaveNoDate.removeAll(keepingCapacity: true)
        }

        if !savingItems.isEmpty || !savingSamples.isEmpty {
            print("items: %3d samples: %3d", savingItems.count, savingSamples.count)
        }

        if !savingItems.isEmpty {
            do {
                try pool.write { db in
                    for case let item as TimelineObject in savingItems {
                        do {
                            try item.save(in: db)
                            if item.lastSaved == nil {
                                item.lastSaved = Date()
                            }
                        }
                        catch PersistenceError.recordNotFound { logger.error("PersistenceError.recordNotFound") }
                        catch let error as DatabaseError where error.resultCode == .SQLITE_CONSTRAINT {
                            logger.error("\(error)")

                            // break the edges and put it back in the queue
                            logger.info("BREAKING ITEM EDGES")
                            (item as? ArcTimelineItem)?.previousItemId = nil
                            (item as? ArcTimelineItem)?.nextItemId = nil
                            saveNoDate(item)

                        } catch {
                            saveNoDate(item)
                        }
                    }
                }

            } catch {
                logger.error("\(error)")
            }
        }

        if !savingSamples.isEmpty {
            do {
                try pool.write { db in
                    for case let sample as TimelineObject in savingSamples {
                        do {
                            try sample.save(in: db)
                            if sample.lastSaved == nil {
                                sample.lastSaved = Date()
                            }

                        } catch PersistenceError.recordNotFound {
                            print("PersistenceError.recordNotFound")

                        } catch {
                            saveNoDate(sample)
                        }
                    }
                }
                
            } catch {
                logger.error("\(error)")
            }
        }
    }

    // MARK: - Counts

    var placesPendingUpdate: Int {
        return countPlaces(where: "needsUpdate = 1")
    }

    var modelsPendingUpdate: Int {
       return countModels(where: "isShared = 0 AND needsUpdate = 1")
    }

    // MARK: - Database migrations

    var arcMigrator = DatabaseMigrator()

    override func migrateDatabases() {
        super.migrateDatabases()

        guard let pool = pool else { fatalError("Attempting to access the database when disconnected") }

        Migrations.addLocoKitMigrations(to: &migrator)
        Migrations.addLocoKitAuxiliaryMigrations(to: &auxiliaryDbMigrator)
        Migrations.addArcMigrations(to: &arcMigrator)

        do {
            try migrator.migrate(pool)
        } catch {
            logger.info("\(error)")
            fatalError()
        }

        do {
            try auxiliaryDbMigrator.migrate(auxiliaryPool)
        } catch {
            logger.info("\(error)")
            fatalError()
        }

        do {
            try arcMigrator.migrate(arcPool)
        } catch {
            logger.info("\(error)")
            fatalError()
        }

        delay(20, onQueue: DispatchQueue.global()) {
            var migrator = DatabaseMigrator()
            Migrations.addDelayedLocoKitMigrations(to: &migrator)
            do {
                try migrator.migrate(pool)
            } catch {
                fatalError()
            }
        }
    }

    //  MARK: -
    
    override var dateFields: [String] {
        return super.dateFields + ["backupLastSaved", "lastVisitEndDate"]
    }
    
    override var boolFields: [String] {
        return super.boolFields + ["restoring", "manualActivityType", "uncertainActivityType", "unknownActivityType", "manualPlace",
                                   "isHome", "isFavourite"]
    }

    // MARK: - Housekeeping

    func housekeep() {
        hardDeleteSoftDeletedObjects()
        deleteStaleSharedModels()
        pruneSampleRTreeRows()
    }

    override func hardDeleteSoftDeletedObjects() {
        process {
            RecordingManager.store.connectToDatabase()
            guard let pool = self.pool else { fatalError("Attempting to access the database when disconnected") }

            do {
                try pool.write { db in
                    try db.execute(sql: "DELETE FROM LocomotionSample WHERE deleted = 1 AND (backupLastSaved IS NULL OR backupLastSaved > lastSaved)")
                }
            } catch {
                logger.error(error, subsystem: .misc)
            }
            do {
                try pool.write { db in
                    try db.execute(sql: "DELETE FROM TimelineItem WHERE deleted = 1 AND (backupLastSaved IS NULL OR backupLastSaved > lastSaved)")
                }
            } catch {
                logger.error(error, subsystem: .misc)
                // don't need these reports, because they're all foreign key constraint fails,
                // which are now handled in new databases by ON DELETE SET NULL
                // logToSentry(error: error)
            }
        }
    }

    // MARK: - Copy database to local container

    func copyDatabasesToLocal() {
        let manager = FileManager.default
        let localDir = try! manager.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true
        )
        let localSQLFile = localDir.appendingPathComponent("LocoKitCopy.sqlite")
        let localWALFile = localDir.appendingPathComponent("LocoKitCopy.sqlite-wal")

        do {
            try manager.removeItem(at: localSQLFile)
            try manager.removeItem(at: localWALFile)
            try manager.copyItem(
                at: RecordingManager.store.dbDir.appendingPathComponent("LocoKit.sqlite"),
                to: localSQLFile
            )
            try manager.copyItem(
                at: RecordingManager.store.dbDir.appendingPathComponent("LocoKit.sqlite-wal"),
                to: localWALFile
            )

        } catch {
            logger.error(error, subsystem: .misc)
        }
    }

}
