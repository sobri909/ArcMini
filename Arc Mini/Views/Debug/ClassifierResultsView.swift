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

    var classifiers: [any DiscreteClassifier] {
        let compositeClassifier = RecordingManager.highlander.recorder.classifier
        return Array(compositeClassifier.discreteClassifiers.sorted { $0.0 > $1.0 }.map { $0.1 })
    }

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Classifiers")) {
                    ForEach(classifiers, id: \.geoKey) { classifier in
                        row(
                            leftText: Text(classifier.geoKey),
                            rightText: Text("\(classifier.totalSamples) [C\(classifier.completenessScore, specifier: "%.2f"), A\(classifier.accuracyScore ?? 0, specifier: "%.2f")]")
                        )
                    }
                }

                if let results = timelineRecorder.lastClassifierResults {
                    Section(header: Text("Most Recent Sample")) {
                        ForEach(results.array) { result in
                            if result.score > 0 {
                                row(
                                    leftText: Text(result.name.displayName.capitalized),
                                    rightText: Text(scoreString(for: result, in: results))
                                )
                                .opacity(result.normalisedScore(in: results).clamped(min: 0.2, max: 1))
                            }
                        }
                    }
                }
            }
            .navigationBarTitle("Arc Mini \(Bundle.versionNumber) (\(String(format: "%d", Bundle.buildNumber)))")
            .environment(\.defaultMinListRowHeight, 34)
        }
    }

    // MARK: -

    func scoreString(for result: ClassifierResultItem, in results: ClassifierResults) -> String {
        return String(format: "%.6f [%.2f]", result.score, result.normalisedScore(in: results))
    }

    func row(leftText: Text, rightText: Text) -> some View {
        HStack {
            leftText.font(.system(size: 13, weight: .regular))
            Spacer()
            rightText.font(.system(size: 13, weight: .regular).monospacedDigit())
        }
        .listRowInsets(EdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 10))
    }
}
