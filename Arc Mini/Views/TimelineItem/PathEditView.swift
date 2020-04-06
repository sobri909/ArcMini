//
//  PathEditView.swift
//  Arc Mini
//
//  Created by Matt Greenfield on 23/3/20.
//  Copyright © 2020 Matt Greenfield. All rights reserved.
//

import SwiftUI
import LocoKit

struct PathEditView: View {

    @ObservedObject var path: ArcPath
    @EnvironmentObject var mapState: MapState
    @EnvironmentObject var timelineState: TimelineState
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>

    var classifierResults: ClassifierResults {
        if let results = path.classifierResults {
            return results
        }
        return ClassifierResults(results: [], moreComing: true)
    }

    var body: some View {
        List {
            ForEach(Array(classifierResults), id: \.name) { result in
                Button(action: {
                    self.path.trainActivityType(to: result.name)
                    self.presentationMode.wrappedValue.dismiss()
                }) {
                    HStack {
                        if self.pathTypeMatches(result) {
                            Text(result.name.displayName.capitalized.localised())
                                .font(.system(size: 17, weight: .semibold))
                        } else {
                            Text(result.name.displayName.capitalized.localised())
                                .font(.system(size: 17, weight: .regular))
                        }
                        Spacer()
                        Text(String(format: "%.0f", result.normalisedScore(in: self.classifierResults) * 100))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(Color(UIColor.arcGray1))
                    }
                }.buttonStyle(RowButtonStyle())
            }
        }
        .navigationBarHidden(true)
        .navigationBarTitle("", displayMode: .inline)
        .onAppear {
            self.mapState.selectedItems = [self.path]
            self.mapState.itemSegments = self.path.segmentsByActivityType
            self.timelineState.backButtonHidden = false
        }
    }

    func pathTypeMatches(_ result: ClassifierResultItem) -> Bool {
        guard path.manualActivityType else { return false }
        return result.name == path.activityType
    }

}

//struct PathEditView_Previews: PreviewProvider {
//    static var previews: some View {
//        PathEditView()
//    }
//}
