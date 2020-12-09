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
                
                // MARK: - Current item, current speed / altitude / etc
                
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
                
                if let stepCountString = stepCountString {
                    row(left: "Steps", right: Text(stepCountString))
                }

                if let ascended = timelineItem.floorsAscended, let descended = timelineItem.floorsDescended, (ascended > 0 || descended > 0) {
                    row(left: "Flights climbed", right: Text(String(format: "%d up, %d down", ascended, descended)))
                }
                
                if let altitude = timelineItem.altitude {
                    row(left: "Altitude", right: Text(String(metres: altitude, isAltitude: true)))
                }
            }
        }
        .padding([.leading, .trailing], 20)
        .background(Color("background"))
        .navigationBarHidden(true)
        .navigationBarTitle("", displayMode: .inline)
        .onAppear {
            if timelineItem.deleted {
                presentationMode.wrappedValue.dismiss()
                return
            }
            mapState.selectedItems = [timelineItem]
            mapState.itemSegments = timelineItem.segmentsByActivityType
            timelineState.mapHeightPercent = TimelineState.subMapHeightPercent
            timelineState.backButtonHidden = false
            timelineState.todayButtonHidden = true
        }
        .onReceive(self.timelineState.$tappedBackButton) { tappedBackButton in
            if tappedBackButton {
                presentationMode.wrappedValue.dismiss()
                timelineState.tappedBackButton = false
            }
        }
    }
    
    // MARK: -
    
    var stepCountString: String? {
        guard let stepCount = timelineItem.stepCount, stepCount > 0 else { return nil }
        if let average = (timelineItem as? ArcVisit)?.place?.averageSteps, average > 0 {
            let pctDiff = (Double(stepCount) / Double(average)) - 1.0
            return String(format: "%@ (%.0f%% %@)",
                          NumberFormatter.localizedString(from: NSNumber(value: stepCount), number: .decimal),
                          abs(pctDiff * 100), pctDiff > 0 ? "up" : "down")
        }
        return NumberFormatter.localizedString(from: NSNumber(value: stepCount), number: .decimal)
    }
    
    // MARK: -
    
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
