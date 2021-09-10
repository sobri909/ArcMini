//
//  TimelineRootView.swift
//  Arc Mini
//
//  Created by Matt Greenfield on 6/4/20.
//  Copyright © 2020 Matt Greenfield. All rights reserved.
//

import SwiftUI

struct TimelineRootView: View {

    var body: some View {
        VStack(spacing: 0) {
            TimelineHeader()
            TimelineScrollView()
            NavigationLink(destination: self.selectedItemDetailsView, isActive: self.$mapState.tappedSelectedItem) {
                EmptyView()
            }
        }
    }

    var selectedItemDetailsView: some View {
        if let selectedItem = mapState.selectedTimelineItem {
            return AnyView(ItemDetailsView(timelineItem: selectedItem))
        }
        return AnyView(EmptyView())
    }

}
