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
        UITableViewCell.appearance().selectionStyle = .none
    }

    var body: some View {
        GeometryReader { metrics in
            NavigationView {
                List {
                    Section(header: TimelineHeader().frame(width: metrics.size.width)) {
                        ForEach(self.segment.timelineItems) { timelineItem in
                            ZStack {
                                self.listBox(for: timelineItem)
                                NavigationLink(destination: ItemDetailsView(timelineItem: timelineItem)) {
                                    EmptyView()
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                }
                .navigationBarTitle("Timeline")
                .navigationBarHidden(true)
            }
        }
    }

    func listBox(for timelineItem: TimelineItem) -> AnyView {
        if let visit = timelineItem as? ArcVisit {
            return AnyView(VisitListBox(visit: visit)
                .listRowInsets(EdgeInsets()))
        }
        if let path = timelineItem as? ArcPath {
            return AnyView(PathListBox(path: path )
                .listRowInsets(EdgeInsets()))
        }
        fatalError("nah")
    }

}

struct TimelineView_Previews: PreviewProvider {
    static var previews: some View {
        TimelineView(segment: AppDelegate.todaySegment)
    }
}
