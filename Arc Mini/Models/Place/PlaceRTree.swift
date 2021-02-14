//
//  PlaceRTree.swift
//  Arc
//
//  Created by Matt Greenfield on 13/2/21.
//  Copyright © 2021 Big Paua. All rights reserved.
//

import GRDB

struct PlaceRTree: MutablePersistableRecord, Encodable {
    var id: Int64?
    var latMin: Double
    var latMax: Double
    var lonMin: Double
    var lonMax: Double

    mutating func didInsert(with rowID: Int64, for column: String?) {
        self.id = rowID
    }
}
