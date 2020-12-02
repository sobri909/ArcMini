//
//  ItemDetailsView.swift
//  Arc Mini
//
//  Created by Matt Greenfield on 19/3/20.
//  Copyright © 2020 Matt Greenfield. All rights reserved.
//

import SwiftUI
import LocoKit

struct ItemDetailsView: View {

    @EnvironmentObject var mapState: MapState
    @EnvironmentObject var timelineState: TimelineState
    @ObservedObject var timelineItem: TimelineItem
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>

    var arcItem: ArcTimelineItem { return timelineItem as! ArcTimelineItem }

    // MARK: -

    init(timelineItem: TimelineItem) {
        self.timelineItem = timelineItem
    }

    // MARK: -

    var body: some View {
        ScrollView(.vertical) {
            LazyVStack(alignment: .leading) {
                ItemDetailsHeader(timelineItem: self.timelineItem)
                HStack {
                    if timelineItem.isVisit {
                        Text("Visit Details").font(.system(size: 18, weight: .semibold))
                    } else {
                        Text("Trip Details").font(.system(size: 18, weight: .semibold))
                    }
                }.frame(height: 44)
                
                /** current item, current speed / altitude / etc **/

                if RecordingManager.recordingState == .recording, timelineItem.isCurrentItem {
                    if let location = timelineItem.samples.last?.location, location.hasUsableCoordinate {
                        row(left: "Current location accuracy", right: Text(String(distance: location.horizontalAccuracy)))

                        if timelineItem is ArcPath, location.horizontalAccuracy >= 0, location.horizontalAccuracy < 100 {
                            row(left: "Current speed", right: Text(String(speed: location.speed)))
                        }

                        if location.verticalAccuracy >= 0 {
                            row(left: "Current altitude", right: Text(String(format: "%@ (+/- %@)",
                                                                             String(metres: location.altitude, isAltitude: true),
                                                                             String(metres: location.verticalAccuracy, isAltitude: true))))
                        }
                    }
                }
                
                if let path = timelineItem as? ArcPath, path.distance > 0 {
                    row(left: "Distance", right: Text(String(format: "%@ at %@",
                                                             String(metres: path.distance, isAltitude: false),
                                                             String(speed: path.speed))))
                }
            }
        }
        .padding([.leading, .trailing], 20)
        .background(Color("background"))
        .navigationBarHidden(true)
        .navigationBarTitle("", displayMode: .inline)
        .onAppear {
            if self.timelineItem.deleted {
                self.presentationMode.wrappedValue.dismiss()
                return
            }
            self.mapState.selectedItems = [self.timelineItem]
            self.mapState.itemSegments = self.timelineItem.segmentsByActivityType
            self.timelineState.mapHeightPercent = TimelineState.subMapHeightPercent
            self.timelineState.backButtonHidden = false
            self.timelineState.todayButtonHidden = true
        }
        .onReceive(self.timelineState.$tappedBackButton) { tappedBackButton in
            if tappedBackButton {
                self.presentationMode.wrappedValue.dismiss()
                self.timelineState.tappedBackButton = false
            }
        }
    }
    
    func row(left leftText: String, right rightText: Text) -> some View {
        return HStack {
            Text(leftText)
                .font(.system(size: 17, weight: .regular))
            Spacer()
            rightText
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Color(UIColor.arcGray1))
        }.frame(height: 44)
    }

}
