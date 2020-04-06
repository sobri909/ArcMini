//
//  TimelineScrollView.swift
//  Arc Mini
//
//  Created by Matt Greenfield on 3/4/20.
//  Copyright © 2020 Matt Greenfield. All rights reserved.
//

import SwiftUI

struct TimelineScrollView: View {

    @EnvironmentObject var timelineState: TimelineState
    @EnvironmentObject var mapState: MapState

    var body: some View {
        PagerView(pageCount: timelineState.dateRanges.count, currentIndex: $timelineState.currentCardIndex) {
            ForEach(timelineState.dateRanges) { dateRange in
                TimelineDayView(timelineSegment: RecordingManager.store.segment(for: dateRange))
            }
        }
    }
    
}

//struct TimelineScrollView_Previews: PreviewProvider {
//    static var previews: some View {
//        TimelineScrollView()
//    }
//}
