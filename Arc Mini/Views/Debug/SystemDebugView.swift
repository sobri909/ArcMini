//
//  SystemDebugView.swift
//  Arc Mini
//
//  Created by Matt Greenfield on 14/4/20.
//  Copyright © 2020 Matt Greenfield. All rights reserved.
//

import SwiftUI
import LocoKit

struct SystemDebugView: View {

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Task Queues")) {
                    self.row(leftText: "Thermal state", rightText: AppDelegate.thermalState.stringValue)
                    self.row(leftText: "Primary queue jobs", rightText: String(describing: Jobs.highlander.primaryQueue.operationCount))
                    self.row(leftText: "Secondary queue jobs", rightText: String(describing: Jobs.highlander.secondaryQueue.operationCount))
                    NavigationLink(destination: PlacesPendingUpdateView()) {
                        self.row(leftText: "Places pending update", rightText: String(describing: RecordingManager.store.placesPendingUpdateCount))
                    }
                    NavigationLink(destination: ModelsPendingUpdateView()) {
                        self.row(leftText: "UD models pending update", rightText: String(describing: RecordingManager.store.modelsPendingUpdateCount))
                    }
                }
            }
            .navigationBarTitle("Arc Mini \(Bundle.versionNumber) (\(Bundle.buildNumber))")
            .environment(\.defaultMinListRowHeight, 28)
        }
    }

    // MARK: -

    func row(leftText: String, rightText: String) -> some View {
        return HStack {
            Text(leftText).font(.system(.footnote))
            Spacer()
            Text(rightText).font(.system(.footnote)).opacity(0.6)
        }
    }

}

struct SystemDebugView_Previews: PreviewProvider {
    static var previews: some View {
        SystemDebugView()
    }
}
