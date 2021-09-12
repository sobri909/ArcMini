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
    @EnvironmentObject var timelineState: TimelineState
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                ItemDetailsHeader(timelineItem: self.path, includeEditButton: false)
                    .padding([.leading, .trailing], 20)
                
                ForEach(Array(classifierResults), id: \.name) { result in
                    Button {
                        self.path.trainActivityType(to: result.name)
                        self.presentationMode.wrappedValue.dismiss()
                    } label: {
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
                    }
                    .padding([.leading, .trailing], 20)
                    .frame(height: 44)
                    .background(Color("background"))
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            if self.path.deleted {
                self.presentationMode.wrappedValue.dismiss()
                return
            }
            MapState.highlander.selectedItems = [self.path]
            MapState.highlander.itemSegments = self.path.segmentsByActivityType
            TimelineState.highlander.backButtonHidden = false
            TimelineState.highlander.todayButtonHidden = true
        }
    }

    // MARK: -
    
    var classifierResults: ClassifierResults {
        if let results = path.classifierResults {
            return results
        }
        return ClassifierResults(results: [], moreComing: true)
    }
    
    func pathTypeMatches(_ result: ClassifierResultItem) -> Bool {
        guard path.manualActivityType else { return false }
        return result.name == path.activityType
    }

}
