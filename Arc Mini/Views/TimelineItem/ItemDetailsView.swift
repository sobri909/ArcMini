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

    @EnvironmentObject var mapState: MapState
    @EnvironmentObject var timelineState: TimelineState
    @ObservedObject var timelineItem: TimelineItem
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>


    var arcItem: ArcTimelineItem { return timelineItem as! ArcTimelineItem }

    // MARK: -

    init(timelineItem: TimelineItem) {
        self.timelineItem = timelineItem
    }

    // MARK: -

    var body: some View {
        List {
            Section(header: ItemDetailsHeader(timelineItem: self.timelineItem)) {
                EmptyView()
            }
        }
        .background(Color("background"))
        .navigationBarHidden(true)
        .navigationBarTitle("", displayMode: .inline)
        .onAppear {
            if self.timelineItem.deleted {
                self.presentationMode.wrappedValue.dismiss()
                return
            }
            self.mapState.selectedItems = [self.timelineItem]
            self.mapState.itemSegments = self.timelineItem.segmentsByActivityType
            self.timelineState.mapHeightPercent = TimelineState.subMapHeightPercent
            self.timelineState.backButtonHidden = false
            self.timelineState.todayButtonHidden = true
        }
        .onReceive(self.timelineState.$tappedBackButton) { tappedBackButton in
            if tappedBackButton {
                self.presentationMode.wrappedValue.dismiss()
                self.timelineState.tappedBackButton = false
            }
        }
    }

}

//struct ItemDetailsView_Previews: PreviewProvider {
//    static var previews: some View {
//        ItemDetailsView()
//    }
//}
