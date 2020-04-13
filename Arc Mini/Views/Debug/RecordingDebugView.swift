//
//  RecordingDebugView.swift
//  Arc Mini
//
//  Created by Matt Greenfield on 12/4/20.
//  Copyright © 2020 Matt Greenfield. All rights reserved.
//

import SwiftUI
import LocoKit

struct RecordingDebugView: View {
    
    var sample: LocomotionSample = LocomotionManager.highlander.locomotionSample()

    var body: some View {
        NavigationView {
            List {
                HStack {
                    Text("Recording state")
                    Spacer()
                    Text(LocomotionManager.highlander.recordingState.rawValue)
                }
            }
            .navigationBarTitle("Arc Mini \(Bundle.versionNumber) (\(Bundle.buildNumber))")
        }
    }

}

struct RecordingDebugView_Previews: PreviewProvider {
    static var previews: some View {
        RecordingDebugView()
    }
}
