//
//  TimelineView.swift
//  Arc Mini
//
//  Created by Matt Greenfield on 6/3/20.
//  Copyright © 2020 Matt Greenfield. All rights reserved.
//

import SwiftUI
import LocoKit

struct TimelineView: View {

    @ObservedObject var segment: TimelineSegment

    init(segment: TimelineSegment) {
        self.segment = segment
        UITableView.appearance().separatorStyle = .none
    }

    var body: some View {
        GeometryReader { metrics in
            List {
                Section(header: TimelineHeader().frame(width: metrics.size.width)) {
                    ForEach(self.segment.timelineItems.reversed(), id: \.itemId) { timelineItem -> AnyView in
                        if timelineItem.isVisit {
                            return AnyView(VisitListBox(visit: timelineItem as! ArcVisit)
                                .listRowInsets(EdgeInsets()))

                        } else {
                            return AnyView(PathListBox(path: timelineItem as! ArcPath)
                                .listRowInsets(EdgeInsets()))
                        }
                    }
                }
            }
            .frame(width: metrics.size.width, height: 400)
        }
    }

}

struct TimelineView_Previews: PreviewProvider {
    static var previews: some View {
        TimelineView(segment: AppDelegate.todaySegment)
    }
}
