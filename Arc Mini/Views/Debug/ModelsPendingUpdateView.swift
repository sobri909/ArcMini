//
//  ModelsPendingUpdateView.swift
//  Arc Mini
//
//  Created by Matt Greenfield on 14/4/20.
//  Copyright © 2020 Matt Greenfield. All rights reserved.
//

import SwiftUI

struct ModelsPendingUpdateView: View {
    var body: some View {
        List(pendingModelNames, id: \.hashValue) { name in
            Text(name)
        }
        .navigationBarTitle("Pending Update")
        .environment(\.defaultMinListRowHeight, 44)
    }

    var pendingModelNames: [String] {
        let names = try? RecordingManager.store.auxiliaryPool.read { db in
            return try String.fetchAll(db, sql: "SELECT geoKey FROM ActivityTypeModel WHERE isShared = 0 AND needsUpdate = 1")
        }
        return names ?? []
    }
}

struct ModelsPendingUpdateView_Previews: PreviewProvider {
    static var previews: some View {
        ModelsPendingUpdateView()
    }
}
