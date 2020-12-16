//
//  ClassifierResultsView.swift
//  Arc Mini
//
//  Created by Matt Greenfield on 16/12/20.
//  Copyright © 2020 Matt Greenfield. All rights reserved.
//

import SwiftUI
import LocoKit

struct ClassifierResultsView: View {
    
    @EnvironmentObject var timelineRecorder: TimelineRecorder

    var body: some View {
        NavigationView {
            List {
                if let results = timelineRecorder.lastClassifierResults {
                    Section(header: Text("Most Recent Sample")) {
                        ForEach(results.array) { result in
                            if result.score > 0 {
                                TextRow(left: Text(result.name.displayName.capitalized),
                                        right: Text("\(result.score, specifier: "%.7f")")
                                            + Text(" [\(result.normalisedScore(in: results), specifier: "%.2f")]"),
                                        leftFont: .system(size: 12, weight: .regular),
                                        rightFont: .system(size: 12, weight: .regular),
                                        height: 28)
                                    .opacity(result.normalisedScore(in: results).clamped(min: 0.2, max: 1))
                                    .listRowInsets(EdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 10))
                            }
                        }
                    }
                }
                
                if let models = userClassifier?.models.sorted(by: { $0.coverageScore > $1.coverageScore }) {
                    Section(header: Text("UD2 Models")) {
                        ForEach(models) { model in
                            if let accuracyScore = model.accuracyScore {
                                TextRow(left: Text(model.geoKey),
                                        right: Text("\(model.totalSamples)")
                                            + Text(" [\(accuracyScore, specifier: "%.2f")]"),
                                        leftFont: .system(size: 12, weight: .regular),
                                        rightFont: .system(size: 12, weight: .regular),
                                        height: 28)
                                    .opacity(model.coverageScore.clamped(min: 0.2, max: 1))
                                    .listRowInsets(EdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 10))
                            } else {
                                TextRow(left: Text(model.geoKey), right: Text("\(model.totalSamples)"),
                                        leftFont: .system(size: 12, weight: .regular),
                                        rightFont: .system(size: 12, weight: .regular),
                                        height: 28)
                                    .opacity(model.coverageScore.clamped(min: 0.2, max: 1))
                                    .listRowInsets(EdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 10))
                            }
                        }
                    }
                }
                
                if let models = sharedClassifier?.models.sorted(by: { $0.coverageScore > $1.coverageScore }) {
                    Section(header: Text("GD2 Models")) {
                        ForEach(models) { model in
                            if let accuracyScore = model.accuracyScore {
                                TextRow(left: Text(model.geoKey),
                                        right: Text("\(model.totalSamples)")
                                            + Text(" [\(accuracyScore, specifier: "%.2f")]"),
                                        leftFont: .system(size: 12, weight: .regular),
                                        rightFont: .system(size: 12, weight: .regular),
                                        height: 28)
                                    .opacity(model.coverageScore.clamped(min: 0.2, max: 1))
                                    .listRowInsets(EdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 10))
                            } else {
                                TextRow(left: Text(model.geoKey), right: Text("\(model.totalSamples)"),
                                        leftFont: .system(size: 12, weight: .regular),
                                        rightFont: .system(size: 12, weight: .regular),
                                        height: 28)
                                    .opacity(model.coverageScore.clamped(min: 0.2, max: 1))
                                    .listRowInsets(EdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 10))
                            }
                        }
                    }
                }
            }
            .listStyle(SidebarListStyle())
            .navigationBarTitle("Arc Mini \(Bundle.versionNumber) (\(String(format: "%d", Bundle.buildNumber)))")
            .environment(\.defaultMinListRowHeight, 28)
        }
    }
    
    var userClassifier: UserActivityTypeClassifier? {
        guard let timelineClassifier = RecordingManager.recorder.classifier as? UserTimelineClassifier else { return nil }
        return timelineClassifier.sampleClassifier
    }
    
    var sharedClassifier: ActivityTypeClassifier? {
        return userClassifier?.parent
    }
    
}
