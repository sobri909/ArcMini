//
//  TimelineDayView.swift
//  Arc Mini
//
//  Created by Matt Greenfield on 6/3/20.
//  Copyright © 2020 Matt Greenfield. All rights reserved.
//

import SwiftUI
import LocoKit

struct TimelineDayView: View {

    @ObservedObject var timelineSegment: TimelineSegment
    @EnvironmentObject var timelineState: TimelineState
    @EnvironmentObject var mapState: MapState

    init(timelineSegment: TimelineSegment) {
        self.timelineSegment = timelineSegment
        UITableViewCell.appearance().selectionStyle = .none
        UITableView.appearance().backgroundColor = UIColor(named: "background")
    }

    var body: some View {
        timelineState.previousListBox = nil
        return ZStack(alignment: .trailing) {
            List {
                ForEach(filteredListItems) { displayItem in
                    listBox(for: displayItem).onAppear {
                        if let visit = displayItem.timelineItem as? ArcVisit, visit.isWorthKeeping {
                            visit.findAPlace()
                        }
                    }.listRowInsets(EdgeInsets())
                }
            }
            Rectangle().fill(Color("brandSecondary10")).frame(width: 0.5).edgesIgnoringSafeArea(.all)
        }
        .navigationBarTitle("")
        .navigationBarHidden(true)
        .onAppear {
            guard timelineState.visibleDateRange == timelineSegment.dateRange else { return }
            mapState.selectedItems.removeAll()
            mapState.itemSegments.removeAll()
            timelineState.backButtonHidden = true
            timelineState.updateTodayButton()
            timelineState.mapHeightPercent = TimelineState.rootMapHeightPercent
        }
        .background(Color("background"))
    }

    var filteredListItems: [DisplayItem] {
        var displayItems: [DisplayItem] = []
        
        var previousWasThinker = false
        for item in timelineSegment.timelineItems.reversed() {
            if item.dateRange == nil { continue }
            if item.invalidated { continue }
            
            let useThinkers = RecordingManager.store.processing || activeItems.contains(item) || item.isMergeLocked

            if item.isWorthKeeping {
                displayItems.append(DisplayItem(timelineItem: item))
                previousWasThinker = false
                
            } else if useThinkers && !previousWasThinker {
                displayItems.append(DisplayItem(thinkerId: item.itemId))
                previousWasThinker = true
            }
        }
        
        return displayItems
    }

    var isToday: Bool {
        return timelineSegment.dateRange?.contains(Date()) == true
    }

    // the items inside the recorder's processing boundary
    var activeItems: [TimelineItem] {
        if isToday, !LocomotionManager.highlander.recordingState.isSleeping, let currentItem = RecordingManager.recorder.currentItem {
            return TimelineProcessor.itemsToProcess(from: currentItem)
        }
        return []
    }

    func listBox(for displayItem: DisplayItem) -> some View {

        // show a "thinking" item for shitty stuff that's still processing or can't be processed yet
        guard let item = displayItem.timelineItem else {
            let box = ThinkingListBox()
            return AnyView(box)
        }
        
        let boxStack = ZStack {
            NavigationLink(destination: ItemDetailsView(timelineItem: item)) {}
            self.timelineItemBox(for: item).onAppear {
                if self.timelineSegment == self.timelineState.visibleTimelineSegment {
                    if item == self.filteredListItems.first?.timelineItem {
                        self.mapState.selectedItems = [] // zoom to all items when scrolled to top
                    } else {
                        self.mapState.selectedItems.insert(item)
                    }
                }
            }.onDisappear {
                if self.timelineSegment == self.timelineState.visibleTimelineSegment {
                    self.mapState.selectedItems.remove(item)
                }
            }
        }
        
        return AnyView(boxStack)
    }

    func timelineItemBox(for item: TimelineItem) -> some View {
        if let visit = item as? ArcVisit {
            let box = VisitListBox(visit: visit)
            timelineState.previousListBox = box
            return AnyView(box)
        }
        if let path = item as? ArcPath {
            let box = PathListBox(path: path)
            timelineState.previousListBox = box
            return AnyView(box)
        }
        fatalError("nah")
    }

    struct DisplayItem: Identifiable {
        var id: UUID
        var timelineItem: TimelineItem?
        
        init(timelineItem: TimelineItem? = nil, thinkerId: UUID? = nil) {
            self.timelineItem = timelineItem
            if let timelineItem = timelineItem {
                id = timelineItem.itemId
            } else {
                id = thinkerId!
            }
        }
    }
    
}
