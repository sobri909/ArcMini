//
//  ItemDetailsView.swift
//  Arc Mini
//
//  Created by Matt Greenfield on 19/3/20.
//  Copyright © 2020 Matt Greenfield. All rights reserved.
//

import SwiftUI
import LocoKit

struct ItemDetailsView: View {

    var timelineItem: TimelineItem

    @ObservedObject var selectedItems: ObservableItems

    init(timelineItem: TimelineItem, selectedItems: ObservableItems) {
        self.timelineItem = timelineItem
        self.selectedItems = selectedItems
    }

    var body: some View {
        Text((timelineItem as! ArcTimelineItem).title)
            .onAppear { self.selectedItems.items.insert(self.timelineItem) }
            .onDisappear { self.selectedItems.items.remove(self.timelineItem) }
    }

}

//struct ItemDetailsView_Previews: PreviewProvider {
//    static var previews: some View {
//        ItemDetailsView()
//    }
//}
