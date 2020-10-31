//
//  Note.swift
//  Arc
//
//  Created by Matt Greenfield on 4/1/19.
//  Copyright © 2019 Big Paua. All rights reserved.
//

import GRDB
import LocoKit

class Note: TimelineObject, Backupable {

    let noteId: UUID
    var date: Date { didSet { hasChanges = true } }
    var body: String { didSet { hasChanges = true } }
    var deleted: Bool { didSet { hasChanges = true } }

    private var _invalidated = false
    public var invalidated: Bool { return _invalidated }
    public func invalidate() { _invalidated = true }

    // MARK: - Init

    init(date: Date = Date(), body: String = "") {
        self.noteId = UUID()
        self.date = date
        self.body = body
        self.deleted = false
        RecordingManager.store.add(self)
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
        
        // Backupable
        self.backupLastSaved = dict["backupLastSaved"] as? Date

        RecordingManager.store.add(self)
    }

    // MARK: - TimelineObject

    var transactionDate: Date?
    var hasChanges: Bool = false
    var lastSaved: Date?

    func save(immediate: Bool = true) {
        guard let pool = store?.pool else { fatalError("Attempting to access the database when disconnected") }
        do {
            try pool.write { db in
                self.transactionDate = Date()
                try self.save(in: db)
                self.lastSaved = self.transactionDate
            }
        } catch {
            logger.error("\(error)")
        }
    }

    func saveNoDate() {
        guard let pool = store?.pool else { fatalError("Attempting to access the database when disconnected") }
        hasChanges = true
        do {
            try pool.write { db in
                try self.save(in: db)
            }
        } catch {
            logger.error("\(error)")
        }
    }

    var source = "ArcMini"
    var objectId: UUID { return noteId }
    var store: TimelineStore? { return RecordingManager.store }

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
        
        // Backupable
        container["backupLastSaved"] = backupLastSaved
    }
    
    // MARK: - Backupable
    
    var backupLastSaved: Date? { didSet { if oldValue != backupLastSaved { saveNoDate() } } }
    static var backupFolderPrefixLength = 1

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
