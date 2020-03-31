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
    @EnvironmentObject var mapState: MapState

    var body: some View {
        Text((timelineItem as! ArcTimelineItem).title)
            .navigationBarItems(trailing: editButton)
            .navigationBarTitle("", displayMode: .inline)
            .onAppear {
                self.mapState.selectedItems.removeAll()
                self.mapState.selectedItems.insert(self.timelineItem)
                self.mapState.itemSegments = self.timelineItem.segmentsByActivityType
        }
    }

    var editButton: AnyView {
        return AnyView(NavigationLink(destination: editView(for: timelineItem)) {
            HStack(alignment: .firstTextBaseline) {
                Image(systemName: "square.and.pencil").foregroundColor(.arcSelected)
                Text("EDIT")
                    .font(.custom("Rubik-Medium", size: 12))
                    .foregroundColor(.arcSelected)
                    .kerning(1)
            }
        })
    }

    func editView(for timelineItem: TimelineItem) -> AnyView {
        if let visit = timelineItem as? ArcVisit {
            return AnyView(VisitEditView(visit: visit, placeClassifier: visit.placeClassifier))
        }
        if let path = timelineItem as? ArcPath, let classifierResults = path.classifierResults {
            return AnyView(PathEditView(path: path, classifierResults: classifierResults))
        }
        return AnyView(EmptyView())
    }

}

//struct ItemDetailsView_Previews: PreviewProvider {
//    static var previews: some View {
//        ItemDetailsView()
//    }
//}
