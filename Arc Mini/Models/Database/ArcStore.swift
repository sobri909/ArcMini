//
//  ArcStore.swift
//  Arc Mini
//
//  Created by Matt Greenfield on 12/3/20.
//  Copyright © 2020 Matt Greenfield. All rights reserved.
//

import GRDB
import LocoKit

final class ArcStore: TimelineStore {

    override var dbDir: URL { get { return arcDbDir } set {} }

    lazy var arcDbDir: URL = {
        if let groupDir = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.ArcApp") { return groupDir }
        return try! FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
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

    var placesInStore: Int { return mutex.sync { placeMap.objectEnumerator()?.allObjects.count ?? 0 } }
    var notesInStore: Int { return mutex.sync { noteMap.objectEnumerator()?.allObjects.count ?? 0 } }
    var userModelsInStore: Int { return mutex.sync { userModelMap.objectEnumerator()?.allObjects.count ?? 0 } }

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
        return try! arcPool.read { db in
            guard let row = try Row.fetchOne(db, sql: query, arguments: arguments) else { return nil }
            return note(for: row)
        }
    }

    public func notes(where query: String, arguments: StatementArguments = StatementArguments()) -> [Note] {
        return notes(for: "SELECT * FROM Note WHERE " + query, arguments: arguments)
    }

    public func notes(for query: String, arguments: StatementArguments = StatementArguments()) -> [Note] {
        return try! arcPool.read { db in
            var notes: [Note] = []
            let rows = try Row.fetchCursor(db, sql: query, arguments: arguments)
            while let row = try rows.next() { notes.append(note(for: row)) }
            return notes
        }
    }

    func countNotes(where query: String = "1", arguments: StatementArguments = StatementArguments()) -> Int {
        return try! arcPool.read { db in
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

        Migrations.addDelayedLocoKitMigrations(to: &migrator)
    }

    //  MARK: -

    override var boolFields: [String] {
        return super.boolFields + ["restoring", "manualActivityType", "uncertainActivityType", "unknownActivityType", "manualPlace",
                                   "isHome", "isFavourite"]
    }

}
