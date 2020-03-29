//
//  SegmentsEditView.swift
//  Arc Mini
//
//  Created by Matt Greenfield on 28/3/20.
//  Copyright © 2020 Matt Greenfield. All rights reserved.
//

import SwiftUI
import LocoKit

struct SegmentsEditView: View {

    var timelineItem: ArcTimelineItem
    @EnvironmentObject var mapState: MapState

    let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()
    
    var body: some View {
        List {
            ForEach(timelineItem.segmentsByActivityType.reversed(), id: \.id) { segment in
                HStack {
                    Circle().fill(Color(segment.activityType?.color ?? UIColor.black)).frame(width: 10, height: 10)
                    if segment.isDataGap {
                        Text("Data Gap".localised())
                            .font(.system(size: 17, weight: .regular))
                            .foregroundColor(.red)

                    } else {
                        Text(segment.activityType?.displayName.capitalized.localised() ?? "Unknown".localised())
                            .font(.system(size: 17, weight: .regular))
                    }
                    Spacer()
                    Text(self.rightText(for: segment))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color(UIColor.arcGray1))
                }
            }
        }
        .navigationBarTitle("", displayMode: .inline)
        .onAppear {
            self.mapState.selectedItems.removeAll()
            self.mapState.selectedItems.insert(self.timelineItem)
            self.mapState.itemSegments = self.timelineItem.segmentsByActivityType
        }
        .onDisappear {
            self.mapState.itemSegments.removeAll()
        }
    }

    func rightText(for segment: ItemSegment) -> String {
        guard let dateRange = segment.dateRange else { return "" }

        if segment.activityType == .bogus {
            return String(duration: dateRange.duration, style: .short)
                + ", " + formatter.string(from: dateRange.start)
        }

        if !segment.hasAnyUsableLocations {
            return "nolo, " + String(duration: dateRange.duration, style: .short)
                + ", " + formatter.string(from: dateRange.start)
        }

        if segment.activityType == .stationary {
            return String(duration: dateRange.duration, style: .short)
                + ", " + formatter.string(from: dateRange.start)
        }

        return String(metres: segment.distance, isAltitude: false)
            + ", " + String(duration: dateRange.duration, style: .short)
            + ", " + formatter.string(from: dateRange.start)
    }

}

//struct SegmentsEditView_Previews: PreviewProvider {
//    static var previews: some View {
//        SegmentsEditView()
//    }
//}
