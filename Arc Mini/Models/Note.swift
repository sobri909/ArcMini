//
//  Note.swift
//  Arc
//
//  Created by Matt Greenfield on 4/1/19.
//  Copyright © 2019 Big Paua. All rights reserved.
//

import GRDB
import LocoKit

class Note: TimelineObject, Encodable {

    let noteId: UUID
    var date: Date { didSet { hasChanges = true } }
    var body: String { didSet { hasChanges = true } }
    var deleted: Bool { didSet { hasChanges = true } }

    // MARK: - Init

    init(date: Date = Date(), body: String = "") {
        self.noteId = UUID()
        self.date = date
        self.body = body
        self.deleted = false
        AppDelegate.store.add(self)
    }

    init(from dict: [String: Any?]) {
        if let uuidString = dict["noteId"] as? String {
            self.noteId = UUID(uuidString: uuidString)!
        } else {
            self.noteId = UUID()
        }
        self.date = dict["date"] as! Date
        self.body = dict["body"] as! String
        self.deleted = dict["deleted"] as? Bool ?? false
        self.lastSaved = dict["lastSaved"] as? Date

        AppDelegate.store.add(self)
    }

    // MARK: - TimelineObject

    var transactionDate: Date?
    var hasChanges: Bool = false
    var lastSaved: Date?

    func save(immediate: Bool = true) {
        do {
            try store?.pool.write { db in
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
            try store?.pool.write { db in
                try self.save(in: db)
            }
        } catch {
            print("ERROR: \(error)")
        }
    }

    var source = "ArcMini"
    var objectId: UUID { return noteId }
    var store: TimelineStore? { return AppDelegate.store }

    // MARK: - PersistableRecord

    public static let databaseTableName = "Note"

    public static var persistenceConflictPolicy: PersistenceConflictPolicy {
        return PersistenceConflictPolicy(insert: .replace, update: .abort)
    }

    open func encode(to container: inout PersistenceContainer) {
        container["noteId"] = noteId.uuidString
        container["date"] = date
        container["source"] = source
        container["body"] = body
        container["deleted"] = deleted
        container["lastSaved"] = transactionDate ?? lastSaved ?? Date()
    }

    // MARK: - Encodable

    enum CodingKeys: String, CodingKey {
        case noteId
        case date
        case body
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(noteId, forKey: .noteId)
        try container.encode(date, forKey: .date)
        try container.encode(body, forKey: .body)
    }

}
