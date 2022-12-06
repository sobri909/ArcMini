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
        List {
            Section("CD2 models") {
                ForEach(pendingCDModelNames, id: \.hashValue) { name in
                    Text(name)
                        .font(.system(size: 13, weight: .regular))
                        .listRowInsets(EdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 10))
                }
            }
            Section("UD2 models") {
                ForEach(pendingUDModelNames, id: \.hashValue) { name in
                    Text(name)
                        .font(.system(size: 13, weight: .regular))
                        .listRowInsets(EdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 10))
                }
            }
        }
        .navigationBarTitle("Pending Update")
        .environment(\.defaultMinListRowHeight, 34)
    }

    var pendingCDModelNames: [String] {
        let names = try? RecordingManager.store.auxiliaryPool.read { db in
            return try String.fetchAll(db, sql: "SELECT geoKey FROM CoreMLModel WHERE needsUpdate = 1")
        }
        return names ?? []
    }

    var pendingUDModelNames: [String] {
        let names = try? RecordingManager.store.auxiliaryPool.read { db in
            return try String.fetchAll(db, sql: "SELECT geoKey FROM ActivityTypeModel WHERE isShared = 0 AND needsUpdate = 1")
        }
        return names ?? []
    }
}
