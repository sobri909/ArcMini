//
//  PlacesPendingUpdateView.swift
//  Arc Mini
//
//  Created by Matt Greenfield on 14/4/20.
//  Copyright © 2020 Matt Greenfield. All rights reserved.
//

import GRDB
import SwiftUI

struct PlacesPendingUpdateView: View {
    var body: some View {
        List(pendingPlaceNames, id: \.hashValue) { name in
            Text(name)
        }
        .navigationBarTitle("Pending Update")
        .environment(\.defaultMinListRowHeight, 44)
    }

    var pendingPlaceNames: [String] {
        let names = try? RecordingManager.store.arcPool.read { db in
            return try String.fetchAll(db, sql: "SELECT name FROM Place WHERE needsUpdate = 1")
        }
        return names ?? []
    }
}
