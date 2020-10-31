//
//  ConcreteBackupable.swift
//  Arc
//
//  Created by Matt Greenfield on 2/10/20.
//  Copyright © 2020 Big Paua. All rights reserved.
//

import LocoKit

struct ConcreteBackupable: Encodable {
    let object: Backupable
    
    func encode(to encoder: Encoder) throws {
        try object.encode(to: encoder)
    }
}
