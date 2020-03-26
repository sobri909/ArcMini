//
//  TrackPlay.swift
//  Arc
//
//  Created by Matt Greenfield on 24/8/19.
//  Copyright © 2019 Big Paua. All rights reserved.
//

import GRDB

class TrackPlay: Record {

    var date: Date
    var name: String
    var artist: String?

    override class var databaseTableName: String { return "TrackPlay" }

    init?(track: LastFm.Track) {
        guard let date = track.date?.date else { return nil }
        self.date = date
        self.name = track.name
        self.artist = track.artist?.name
        super.init()
    }

    required init(row: Row) {
        self.date = row["date"]
        self.name = row["name"]
        self.artist = row["artist"]
        super.init(row: row)
    }

    override func encode(to container: inout PersistenceContainer) {
        container["date"] = date
        container["name"] = name
        container["artist"] = artist
    }

}
