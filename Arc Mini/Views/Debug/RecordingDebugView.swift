//
//  RecordingDebugView.swift
//  Arc Mini
//
//  Created by Matt Greenfield on 12/4/20.
//  Copyright © 2020 Matt Greenfield. All rights reserved.
//

import SwiftUI
import LocoKit
import CoreLocation

struct RecordingDebugView: View {
    
    var sample: LocomotionSample = LocomotionManager.highlander.locomotionSample()

    var loco: LocomotionManager { return LocomotionManager.highlander }

    var body: some View {
        NavigationView {
            List {
                if let appGroup = LocomotionManager.highlander.appGroup {
                    Section(header: Text("App Group")) {
                        ForEach(appGroup.sortedApps, id: \.updated) { appState in
                            self.row(
                                leftText: appState.appName.rawValue,
                                rightText: "\(appState.recordingState.rawValue) (\(String(duration: appState.updated.age)) ago)",
                                highlight: appState.isAliveAndRecording, fade: !appState.isAlive
                            )
                        }
                    }
                }

                Section(header: Text(loco.recordingState.rawValue.capitalized)) {
                    self.row(leftText: "Thermal state", rightText: AppDelegate.thermalState.stringValue)
                    self.row(leftText: "Target samples per minute", rightText: "\(RecordingManager.recorder.samplesPerMinute)")
                    if loco.recordingState == .sleeping {
                        self.row(leftText: "Sleep cycle duration", rightText: String(duration: loco.sleepCycleDuration))
                        self.leavingProbabilityRow
                    }
                }
                Section(header: Text("Location")) {
                    self.row(leftText: "Requesting", rightText: self.desiredAccuracyString)
                    self.horizontalAccuracyRow
                    self.verticalAccuracyRow
                    self.trustFactorRow
                }
                
                let sample = RecordingManager.highlander.loco.locomotionSample()

                if LocomotionManager.highlander.recordingState == .recording || LocomotionManager.highlander.recordingState == .wakeup {
                    Section(header: Text(String(format: "Sample Glance (%@)", sample.movingState.rawValue))) {
                        self.row(leftText: "Present", rightText: String(describing: sample))
                        self.row(leftText: "Behind now", rightText: String(duration: sample.date.age))
                        if let speed = sample.location?.speed, speed >= 0 {
                            self.row(leftText: "Speed", rightText: String(speed: speed))
                        }
                    }
                }
            }
            .listStyle(SidebarListStyle())
            .navigationBarTitle("Arc Mini \(Bundle.versionNumber) (\(String(format: "%d", Bundle.buildNumber)))")
            .environment(\.defaultMinListRowHeight, 28)
        }
    }

    var desiredAccuracyString: String {
        let requesting = LocomotionManager.highlander.locationManager.desiredAccuracy
        if requesting == Double.greatestFiniteMagnitude {
            return "Double.greatestFiniteMagnitude"
        }
        return String(format: "%.0fm", requesting)
    }

    func trustFactor(for location: CLLocation) -> Double? {
        guard let trustFactor = LocomotionManager.highlander.coordinateAssessor?.trustFactorFor(location.coordinate) else { return nil }
        guard trustFactor < 1 else { return nil }
        return trustFactor
    }

    var trustFactorRow: AnyView {
        guard let location = sample.location else { return AnyView(SwiftUI.EmptyView()) }
        guard let trustFactor = trustFactor(for: location) else { return AnyView(SwiftUI.EmptyView()) }
        return AnyView(row(leftText: "Trust factor", rightText: String(format: "%.1f", trustFactor)))
    }

    var horizontalAccuracyRow: AnyView {
        guard let location = sample.location else { return AnyView(SwiftUI.EmptyView()) }
        if let trustFactor = trustFactor(for: location) {
            let fudge = 100.0 * (1.0 - trustFactor)
            return AnyView(row(leftText: "Receiving horizontal accuracy",
                               rightText: String(format: "%.0fm (%.0fm)", location.horizontalAccuracy, location.horizontalAccuracy - fudge)))
        }
        return AnyView(row(leftText: "Receiving horizontal accuracy", rightText: String(format: "%.0fm", location.horizontalAccuracy)))
    }

    var verticalAccuracyRow: AnyView {
        guard let location = sample.location else { return AnyView(SwiftUI.EmptyView()) }
        return AnyView(row(leftText: "Receiving vertical accuracy", rightText: String(format: "%.0fm", location.verticalAccuracy)))
    }

    var leavingProbabilityRow: AnyView {
        guard let currentVisit = RecordingManager.highlander.currentVisit else { return AnyView(SwiftUI.EmptyView()) }
        guard let mightLeave = currentVisit.leavingProbabilityNow else { return AnyView(SwiftUI.EmptyView()) }
        return AnyView(row(leftText: "Leaving probability", rightText: String(format: "%.2f", mightLeave)))
    }

    // MARK: -

    func row(leftText: String, rightText: String, highlight: Bool = false, fade: Bool = false) -> some View {
        let font: Font = highlight ? .system(size: 12, weight: .bold) : .system(size: 12, weight: .regular)
        return HStack {
            Text(leftText).font(font).opacity(fade ? 0.6 : 1)
            Spacer()
            Text(rightText).font(font).opacity(0.6).opacity(fade ? 0.6 : 1)
        }
        .frame(height: 28)
        .listRowInsets(EdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 10))
    }

}
