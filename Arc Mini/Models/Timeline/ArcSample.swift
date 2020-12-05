//
//  ArcSample.swift
//  LearnerCoacher
//
//  Created by Matt Greenfield on 21/01/18.
//  Copyright © 2018 Big Paua. All rights reserved.
//

import GRDB
import LocoKit
import CoreLocation

class ArcSample: PersistentSample, Backupable {

    var arcStore: ArcStore? { return store as? ArcStore }

    // MARK: PersistentObject initialiser
    
    required init(from dict: [String: Any?]) {
        self.backupLastSaved = dict["backupLastSaved"] as? Date
        super.init(from: dict)
    }

    // MARK: LocomotionSample initialisers

    required init(from sample: ActivityBrainSample) { super.init(from: sample) }
    
    required init(date: Date, location: CLLocation? = nil, movingState: MovingState = .uncertain,
                  recordingState: RecordingState) {
        super.init(date: date, location: location, movingState: movingState, recordingState: recordingState)
    }

    // MARK: Codable

    required init(from decoder: Decoder) throws {
        try super.init(from: decoder)
    }

    override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
    }
    
    // MARK: - Backupable
    
    static var backupFolderPrefixLength = 3
    var backupLastSaved: Date? { didSet { if oldValue != backupLastSaved { saveNoDate() } } }

    public func saveNoDate() {
        hasChanges = true
        arcStore?.saveNoDate(self)
    }

    // MARK: Persistable

    override func encode(to container: inout PersistenceContainer) {
        super.encode(to: &container)
        container["backupLastSaved"] = backupLastSaved
    }
}

