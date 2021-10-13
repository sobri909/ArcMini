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
    @State var tappedSplitButton = false

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                Spacer().frame(height: 24)
                Text("Edit Segment")
                    .font(.system(size: 24, weight: .bold))
                    .frame(height: 30)
                HStack(spacing: 0) {
                    splitButton
                    Spacer()
                    promoteButton
                }
                Rectangle().fill(Color("brandSecondary10")).frame(height: 0.5)
                Spacer().frame(height: 24)
            }
            .padding([.leading, .trailing], 20)
            .background(Color("background"))
            
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(classifierResults), id: \.name) { result in
                    Button {
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
                    } label: {
                        HStack {
                            if itemSegment.activityType == result.name {
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
                    .listRowInsets(EdgeInsets())
                    .background(Color("background"))
                }
                Spacer().frame(height: 40)
            }
        }
        .background(Color("background"))
        .edgesIgnoringSafeArea(.all)
        .navigationBarHidden(true)
        .onAppear {
            if let timelineItem = itemSegment.timelineItem {
                MapState.highlander.selectedItems = [timelineItem]
            } else {
                MapState.highlander.selectedItems = []
            }
            MapState.highlander.itemSegments = [itemSegment]
            TimelineState.highlander.backButtonHidden = false
            TimelineState.highlander.todayButtonHidden = true
        }
        .onReceive(TimelineState.highlander.$tappedBackButton) { tappedBackButton in
            if tappedBackButton {
                presentationMode.wrappedValue.dismiss()
                TimelineState.highlander.tappedBackButton = false
            }
        }
    }
    
    // MARK: - Buttons

    var splitButton: some View {
        ZStack(alignment: .leading) {
            Button {
                self.tappedSplitButton = true
            } label: {
                HStack(alignment: .center) {
                    Image(systemName: "scissors")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundColor(Color("brandSecondary80"))
                        .frame(width: 24, height: 24)
                    Text("Split")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(Color("brandSecondaryDark"))
                }
            }
            .frame(height: 64)
            NavigationLink(destination: ItemSegmentSplitView(itemSegment: itemSegment), isActive: $tappedSplitButton) {
                EmptyView()
            }.hidden()
        }
    }
    
    var promoteButton: some View {
        ZStack(alignment: .leading) {
            Button {
                // TODO
            } label: {
                HStack(alignment: .center) {
                    Image(systemName: "square.and.arrow.up.on.square")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundColor(Color("brandSecondary80"))
                        .frame(width: 24, height: 24)
                        .offset(x: 0, y: -1.5)
                    Text("Promote")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(Color("brandSecondaryDark"))
                }
            }
            .frame(height: 64)
        }
    }
    
}
