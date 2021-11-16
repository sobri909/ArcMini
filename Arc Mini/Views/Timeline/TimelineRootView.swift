//
//  TimelineRootView.swift
//  Arc Mini
//
//  Created by Matt Greenfield on 6/4/20.
//  Copyright © 2020 Matt Greenfield. All rights reserved.
//

import SwiftUI

struct TimelineRootView: View {

    // TODO: need to get map item tapping to details view back,
    // without triggering view updates that invalidate the nav tree. sigh
    @EnvironmentObject var mapSelection: MapSelection
    
    var body: some View {
        VStack(spacing: 0) {
            TimelineHeader()
            TimelineScrollView()
            NavigationLink(destination: selectedItemDetailsView, isActive: $mapSelection.tappedSelectedItem) {
                EmptyView()
            }
        }
    }

    var selectedItemDetailsView: some View {
        if let selectedItem = mapSelection.selectedTimelineItem {
            return AnyView(ItemDetailsView(timelineItem: selectedItem))
        }
        return AnyView(EmptyView())
    }

}
