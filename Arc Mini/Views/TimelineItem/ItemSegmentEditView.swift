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
    var splittingSegment = false
    var splitActivityType: Binding<ActivityTypeName?>? = .constant(nil)
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                Spacer().frame(height: 24)
                Text(splittingSegment ? "Activity Type" : "Edit Segment")
                    .font(.system(size: 24, weight: .bold))
                    .frame(height: 30)
                if splittingSegment {
                    Spacer().frame(height: 16)
                } else {
                    HStack(spacing: 0) {
                        splitButton
                        Spacer()
                        promoteButton
                    }
                }
                Rectangle().fill(Color("brandSecondary10")).frame(height: 0.5)
                Spacer().frame(height: 24)
            }
            .padding([.leading, .trailing], 20)
            .background(Color("background"))
            
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(itemSegment.classifierResults!), id: \.name) { result in
                    Button {
                        if splittingSegment {
                            splitActivityType?.wrappedValue = result.name
                        } else {
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
                        }
                        delay(0.1) { self.presentationMode.wrappedValue.dismiss() }
                    } label: {
                        HStack {
                            if itemSegment.activityType == result.name {
                                Text(result.name.displayName.capitalized.localised())
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundColor(Color("blackWhiteText"))
                            } else {
                                Text(result.name.displayName.capitalized.localised())
                                    .font(.system(size: 17, weight: .regular))
                                    .foregroundColor(Color("blackWhiteText"))
                            }
                            Spacer()
                            Text(String(format: "%.0f", result.normalisedScore(in: itemSegment.classifierResults!) * 100))
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
            if TimelineState.highlander.popToDetailsView {
                presentationMode.wrappedValue.dismiss()
                return
            }
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
            NavigationLink(destination: ItemSegmentSplitView(itemSegment: itemSegment)) {
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
