//
//  ItemSegmentSplitView.swift
//  Arc Mini
//
//  Created by Matt Greenfield on 7/10/21.
//  Copyright © 2021 Matt Greenfield. All rights reserved.
//

import SwiftUI
import LocoKit

struct ItemSegmentSplitView: View {
    
    var itemSegment: ItemSegment
    @StateObject var leftSegment = ItemSegment(samples: [])
    @StateObject var rightSegment = ItemSegment(samples: [])
    @State var sliderValue = 0.5
    @State var manualLeftActivityType: ActivityTypeName?
    @State var manualRightActivityType: ActivityTypeName?
    @State var leftDateString = ""
    @State var rightDateString = ""
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    
    // MARK: -
    
    var leftActivityType: ActivityTypeName {
        return manualLeftActivityType ?? leftSegment.activityType ?? .stationary
    }

    var rightActivityType: ActivityTypeName {
        return manualRightActivityType ?? rightSegment.activityType ?? .stationary
    }
    
    // MARK: -
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Group {
                Spacer().frame(height: 24)
                HStack {
                    Text("Split Segment")
                        .font(.system(size: 24, weight: .bold))
                        .frame(height: 30)
                    Spacer()
                    doneButton
                }
                Rectangle().fill(Color("brandSecondary10")).frame(height: .onePixel)
                Spacer().frame(height: 24)
                
                HStack {
                    Text(leftDateString).font(.system(size: 13, weight: .regular))
                    Spacer()
                    Text(rightDateString).font(.system(size: 13, weight: .regular))
                }
                HStack {
                    Text(String(duration: leftSegment.duration, style: .short, alwaysIncludeSeconds: true))
                        .font(.system(size: 13, weight: .regular))
                    Spacer()
                    Text(String(duration: rightSegment.duration, style: .short, alwaysIncludeSeconds: true))
                        .font(.system(size: 13, weight: .regular))
                }
                
                Slider(value: $sliderValue, in: 0...1) { _ in
                    movedSlider()
                }
                
                HStack {
                    Spacer().overlay(
                        HStack {
                            Text("\(leftSegment.samples.count) samples")
                                .font(.system(size: 13, weight: .regular))
                            Spacer()
                        }
                    )
                    leftNudgeButton
                    Text("Nudge")
                    rightNudgeButton
                    Spacer().overlay(
                        HStack {
                            Spacer()
                            Text("\(rightSegment.samples.count) samples")
                                .font(.system(size: 13, weight: .regular))
                        }
                    )
                }
            }
            .padding([.leading, .trailing], 20)
            
            Group {
                Spacer().frame(height: 8)
                Rectangle().fill(Color("brandSecondary10")).frame(height: 6)
                Spacer().frame(height: 24)
            }
            
            Group {
                Text("Activity Types")
                    .font(.system(size: 18, weight: .bold))
                Spacer().frame(height: 12)
                
                Button {
                    // TODO
                } label: {
                    HStack {
                        Text("Left segment")
                            .font(.system(size: 17, weight: .regular))
                            .foregroundColor(Color("blackWhiteText"))
                        Spacer()
                        let activityType: ActivityTypeName = leftSegment.activityType ?? .stationary
                        Text(activityType.displayName.capitalized.localised())
                            .font(.system(size: 17, weight: .regular))
                            .foregroundColor(Color("blackWhiteText"))
                            .opacity(0.6)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 18, weight: .regular))
                            .foregroundColor(Color("brandSecondary80"))
                            .frame(width: 24, height: 24)
                    }
                    .frame(height: 44)
                }
                
                Button {
                    // TODO
                } label: {
                    HStack {
                        Text("Right segment")
                            .font(.system(size: 17, weight: .regular))
                            .foregroundColor(Color("blackWhiteText"))
                        Spacer()
                        let activityType: ActivityTypeName = rightSegment.activityType ?? .stationary
                        Text(activityType.displayName.capitalized.localised())
                            .font(.system(size: 17, weight: .regular))
                            .foregroundColor(Color("blackWhiteText"))
                            .opacity(0.6)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 18, weight: .regular))
                            .foregroundColor(Color("brandSecondary80"))
                            .frame(width: 24, height: 24)
                    }
                    .frame(height: 44)
                }
            }
            .padding([.leading, .trailing], 20)
                
            Spacer()
        }
        .background(Color("background"))
        .edgesIgnoringSafeArea(.all)
        .navigationBarHidden(true)
        .onAppear {
            movedSlider()
            MapState.highlander.itemSegments = [leftSegment, rightSegment]
        }
        .onReceive(TimelineState.highlander.$tappedBackButton) { tappedBackButton in
            if tappedBackButton {
                presentationMode.wrappedValue.dismiss()
                TimelineState.highlander.tappedBackButton = false
            }
        }
    }
    
    var doneButton: some View {
        ZStack(alignment: .leading) {
            Button {
                tappedDone()
            } label: {
                HStack(alignment: .center) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundColor(Color("brandSecondary80"))
                        .frame(width: 24, height: 24)
                    Text("Done")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(Color("brandSecondaryDark"))
                }
            }
            .frame(height: 64)
        }
    }
    
    var leftNudgeButton: some View {
        Button {
            tappedLeftNudge()
        } label: {
            HStack(alignment: .center) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundColor(Color("brandSecondary80"))
                    .frame(width: 24, height: 24)
            }
        }
        .frame(height: 64)
    }
    
    var rightNudgeButton: some View {
        Button {
            tappedRightNudge()
        } label: {
            HStack(alignment: .center) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundColor(Color("brandSecondary80"))
                    .frame(width: 24, height: 24)
            }
        }
        .frame(height: 64)
    }
    
    // MARK: = Actions
    
    func movedSlider() {
        guard let startDate = itemSegment.startDate else { return }

        let valueDuration = itemSegment.duration * TimeInterval(sliderValue)
        let boundaryDate = startDate + valueDuration

        var leftSamples: [PersistentSample] = []
        var rightSamples: [PersistentSample] = []
        
        print("value: \(sliderValue)")

        for sample in itemSegment.samples {
            if sample.date < boundaryDate {
                leftSamples.append(sample)
            } else {
                rightSamples.append(sample)
            }
        }

        leftSegment.samples = leftSamples
        rightSegment.samples = rightSamples
        
        if let timelineItem = itemSegment.timelineItem as? ArcTimelineItem {
            if let dateRange = leftSegment.dateRange {
                leftDateString = timelineItem.dateString(for: dateRange.start, timeStyle: .short)! + " – "
                + timelineItem.dateString(for: dateRange.end, timeStyle: .medium)!
            } else {
                leftDateString = "-"
            }
            if let dateRange = rightSegment.dateRange {
                rightDateString = timelineItem.dateString(for: dateRange.start, timeStyle: .medium)! + " – "
                + timelineItem.dateString(for: dateRange.end, timeStyle: .short)!
            } else {
                rightDateString = "-"
            }
        }
        
        // doing here, because can't do at View init. grr
        leftSegment.timelineItem = itemSegment.timelineItem
        rightSegment.timelineItem = itemSegment.timelineItem
        
        // trigger a map update
        MapState.highlander.itemSegments = [leftSegment, rightSegment]
    }
    
    func tappedLeftNudge() {
        guard let sample = leftSegment.samples.last else { return }
        leftSegment.remove(sample)
        rightSegment.add(sample)
        updateSliderValue()
    }

    func tappedRightNudge() {
        guard let sample = rightSegment.samples.first else { return }
        rightSegment.remove(sample)
        leftSegment.add(sample)
        updateSliderValue()
    }
    
    func updateSliderValue() {
        guard let leftDateRange = leftSegment.dateRange else { return }
        guard let rightDateRange = rightSegment.dateRange else { return }
        let boundaryDate = leftDateRange.end + (rightDateRange.start - leftDateRange.end) * 0.5
        let boundaryDuration = boundaryDate - leftDateRange.start
        let value = boundaryDuration / itemSegment.duration
        sliderValue = value
        movedSlider()
    }
    
    func tappedDone() {
        if let manualLeftActivityType = manualLeftActivityType {
            leftSegment.trainActivityType(to: manualLeftActivityType)
        }
        if let manualRightActivityType = manualRightActivityType {
            rightSegment.trainActivityType(to: manualRightActivityType)
        }
        presentationMode.wrappedValue.dismiss()
    }
    
}
