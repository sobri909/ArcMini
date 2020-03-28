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
    @ObservedObject var selectedItems: ObservableItems
    @State private var listOffset: CGRect = CGRect()

    init(segment: TimelineSegment, selectedItems: ObservableItems) {
        self.segment = segment
        self.selectedItems = selectedItems
        UITableView.appearance().separatorStyle = .none
        UITableViewCell.appearance().selectionStyle = .none
    }

    var body: some View {
        GeometryReader { metrics in
            NavigationView {
                List {
                    EmptyView().background(GeometryGetter(rect: self.$listOffset))
                    Section(header: TimelineHeader().frame(width: metrics.size.width)) {
                        ForEach(self.filteredListItems) { timelineItem in
                            ZStack {
                                self.listBox(for: timelineItem)
                                NavigationLink(destination: ItemDetailsView(timelineItem: timelineItem, selectedItems: self.selectedItems)) {
                                    EmptyView()
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                }
                .onAppear { self.selectedItems.items.removeAll() }
                .navigationBarTitle("")
                .navigationBarHidden(true)
            }
        }
    }

    // TODO: need "thinking..." boxes represented in the list array somehow
    var filteredListItems: [TimelineItem] {
        return self.segment.timelineItems.reversed().filter { $0.dateRange != nil }
    }

    func listBox(for timelineItem: TimelineItem) -> AnyView {
        if let visit = timelineItem as? ArcVisit {
            return AnyView(VisitListBox(visit: visit)
                .listRowInsets(EdgeInsets()))
        }
        if let path = timelineItem as? ArcPath {
            return AnyView(PathListBox(path: path)
                .listRowInsets(EdgeInsets()))
        }
        fatalError("nah")
    }

}

//struct TimelineView_Previews: PreviewProvider {
//    static var previews: some View {
//        TimelineView(segment: AppDelegate.todaySegment)
//    }
//}
