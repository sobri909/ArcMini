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

    // MARK: - Views
    
    var body: some View {
        ZStack(alignment: .trailing) {
            List {
                let top = Rectangle()
                    .frame(height: 20).opacity(0)
                    .background(Color("background"))
                    .listRowInsets(EdgeInsets())
                    .onAppear { TimelineState.highlander.timelineScrolledToTop = true }
                    .onDisappear { TimelineState.highlander.timelineScrolledToTop = false }
                
                if #available(iOS 15.0, *) {
                    top.listRowSeparator(.hidden)
                } else {
                    top
                }
                
                ForEach(filteredListItems) { displayItem in
                    let box = listBox(for: displayItem).onAppear {
                        if let visit = displayItem.timelineItem as? ArcVisit, visit.isWorthKeeping {
                            visit.findAPlace()
                        }
                    }
                    .listRowInsets(EdgeInsets())
                    
                    if #available(iOS 15.0, *) {
                        box.listRowSeparator(.hidden)
                    } else {
                        box
                    }
                }
            }
            .listStyle(.plain)
            .environment(\.defaultMinListRowHeight, 0)
            Rectangle().fill(Color("brandSecondary10")).frame(width: 0.5).edgesIgnoringSafeArea(.all)
        }
        .background(Color("background"))
        .edgesIgnoringSafeArea(.all)
        .navigationBarHidden(true)
        .onAppear { updateForAppear() }
        .onDisappear { updateForDisappear() }
        .onReceive(TimelineState.highlander.$currentCardIndex) { _ in
            updateForCurrentCardIndex()
        }
    }

    var filteredListItems: [DisplayItem] {
        var displayItems: [DisplayItem] = []
        
        var previousWasThinker = false
        var previousWasPath = false
        for item in timelineSegment.timelineItems.reversed() {
            if item.dateRange == nil { continue }
            if item.invalidated { continue }
            
            let useThinkers = RecordingManager.store.processing || activeItems.contains(item) || item.isMergeLocked

            if item.isWorthKeeping {
                if previousWasPath, item.isPath {
                    displayItems.append(.spacer)
                }
                displayItems.append(DisplayItem(timelineItem: item))
                previousWasThinker = false
                previousWasPath = item.isPath
                
            } else if useThinkers && !previousWasThinker {
                displayItems.append(DisplayItem(thinkerId: item.itemId))
                previousWasThinker = true
                previousWasPath = true // thinker looks same as path, so needs spacer
            }
        }
        
        return displayItems
    }

    func listBox(for displayItem: DisplayItem) -> some View {
        if displayItem.isSpacer {
            let box = Spacer().frame(maxWidth: .infinity, maxHeight: 16).background(Color("background"))
            return AnyView(box)
        }

        // show a "thinking" item for shitty stuff that's still processing or can't be processed yet
        guard let item = displayItem.timelineItem else {
            let box = ThinkingListBox()
            return AnyView(box)
        }
        
        let boxStack = ZStack {
            NavigationLink(destination: ItemDetailsView(timelineItem: item)) {}
            self.timelineItemBox(for: item)
                .onAppear {
                    if self.timelineSegment == TimelineState.highlander.visibleTimelineSegment {
                        TimelineState.highlander.visibleItems.insert(item)
                        DispatchQueue.main.asyncDeduped(target: self.timelineSegment, after: 0.2) {
                            self.updateSelectedItems()
                        }
                    }
                }.onDisappear {
                    if self.timelineSegment == TimelineState.highlander.visibleTimelineSegment {
                        TimelineState.highlander.visibleItems.remove(item)
                        DispatchQueue.main.asyncDeduped(target: self.timelineSegment, after: 0.2) {
                            self.updateSelectedItems()
                        }
                    }
                }
        }
        
        return AnyView(boxStack)
    }

    func timelineItemBox(for item: TimelineItem) -> some View {
        if let visit = item as? ArcVisit {
            let box = VisitListBox(visit: visit)
            return AnyView(box)
        }
        if let path = item as? ArcPath {
            let box = PathListBox(path: path)
            return AnyView(box)
        }
        fatalError("nah")
    }
    
    // MARK: - Actions
    
    func updateForAppear() {
        timelineSegment.startUpdating()
        MapState.highlander.selectedItems.removeAll()
        MapState.highlander.itemSegments.removeAll()
        TimelineState.highlander.visibleItems.removeAll()
        TimelineState.highlander.backButtonHidden = true
        TimelineState.highlander.updateTodayButton()
        TimelineState.highlander.mapHeightPercent = TimelineState.rootMapHeightPercent
    }
    
    func updateForDisappear() {
        timelineSegment.stopUpdating()
    }
    
    func updateForCurrentCardIndex() {
        if TimelineState.highlander.visibleDateRange == timelineSegment.dateRange {
            updateForAppear()
        } else {
            updateForDisappear()
        }
    }
    
    func updateSelectedItems() {
        guard self.timelineSegment == TimelineState.highlander.visibleTimelineSegment else { return }

        if TimelineState.highlander.timelineScrolledToTop {
            MapState.highlander.selectedItems = [] // zoom to all items when scrolled to top
        } else {
            MapState.highlander.selectedItems = TimelineState.highlander.visibleItems
        }
    }

    // MARK: -
    
    struct DisplayItem: Identifiable {
        var id: UUID
        var timelineItem: TimelineItem?
        var isSpacer = false
        
        static var spacer: DisplayItem {
            return DisplayItem(spacer: true)
        }
        
        init(timelineItem: TimelineItem? = nil, thinkerId: UUID? = nil, spacer: Bool = false) {
            if spacer {
                isSpacer = true
                id = UUID()
                return
            }
            
            self.timelineItem = timelineItem
            
            if let timelineItem = timelineItem {
                id = timelineItem.itemId
            } else {
                id = thinkerId!
            }
        }
    }
    
}
