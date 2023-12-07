//
//  ModelsPendingUpdateView.swift
//  Arc Mini
//
//  Created by Matt Greenfield on 14/4/20.
//  Copyright © 2020 Matt Greenfield. All rights reserved.
//

import SwiftUI
import LocoKit

struct ModelsPendingUpdateView: View {
    @State var updating: Set<String> = []

    var body: some View {
        List {
            Section("Core ML models") {
                ForEach(pendingCDModelNames, id: \.hashValue) { name in
                    Button {
                        updateModel(geoKey: name)
                    } label: {
                        HStack {
                            Text(name)
                                .font(.system(size: 13, weight: .regular))
                                .foregroundStyle(Color.primary)
                            Spacer()
                            if updating.contains(name) {
                                Text("updating...")
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundStyle(Color.primary)
                                    .opacity(0.6)
                            }
                        }
                    }
                    .disabled(updating.contains(name))
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

    func updateModel(geoKey: String) {
        let model = RecordingManager.store.coreMLModel(where: "geoKey = ?", arguments: [geoKey])
        updating.insert(geoKey)
        model?.updateTheModel()
    }

}
