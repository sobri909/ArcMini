//
//  ItemSegmentEditView.swift
//  Arc Mini
//
//  Created by Matt Greenfield on 30/3/20.
//  Copyright © 2020 Matt Greenfield. All rights reserved.
//

import SwiftUI
import LocoKit

struct ItemSegmentEditView: View {

    var itemSegment: ItemSegment
    var classifierResults: ClassifierResults
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    
    var body: some View {
        List {
            ForEach(Array(classifierResults), id: \.name) { result in
                Button(action: {
                    self.itemSegment.trainActivityType(to: result.name)
                    (self.itemSegment.timelineItem as? ArcTimelineItem)?.brexit(self.itemSegment) { newItem in
                        guard let path = newItem as? ArcPath else { return }
                        path._manualActivityType = true
                        path._needsUserCleanup = false
                        path._uncertainActivityType = false
                        path._unknownActivityType = false
                        path.save()
                        TimelineProcessor.process(from: path)
                    }
                    self.presentationMode.wrappedValue.dismiss()
                }) {
                    HStack {
                        Text(result.name.displayName.capitalized.localised())
                            .font(.system(size: 17, weight: .regular))
                        Spacer()
                        Text(String(format: "%.0f", result.normalisedScore(in: self.classifierResults) * 100))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(Color(UIColor.arcGray1))
                    }
                }
                .padding([.leading, .trailing], 20)
                .frame(height: 44)
                .listRowInsets(EdgeInsets())
                .background(Color("background"))
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            if let timelineItem = self.itemSegment.timelineItem {
                MapState.highlander.selectedItems = [timelineItem]
            } else {
                MapState.highlander.selectedItems = []
            }
            MapState.highlander.itemSegments = [self.itemSegment]
            TimelineState.highlander.backButtonHidden = false
            TimelineState.highlander.todayButtonHidden = true
        }
        .onReceive(TimelineState.highlander.$tappedBackButton) { tappedBackButton in
            if tappedBackButton {
                self.presentationMode.wrappedValue.dismiss()
                TimelineState.highlander.tappedBackButton = false
            }
        }
    }

}
