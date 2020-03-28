//
//  ItemDetailsView.swift
//  Arc Mini
//
//  Created by Matt Greenfield on 19/3/20.
//  Copyright © 2020 Matt Greenfield. All rights reserved.
//

import SwiftUI
import LocoKit
import Introspect

struct ItemDetailsView: View {

    var timelineItem: TimelineItem
    @ObservedObject var selectedItems: ObservableItems

    var body: some View {
        Text((timelineItem as! ArcTimelineItem).title)
            .introspectNavigationController { nav in
                nav.isNavigationBarHidden = false
                nav.navigationBar.tintColor = .arcSelected
            }
            .navigationBarItems(trailing:
                NavigationLink(destination: editView(for: timelineItem)) {
                    HStack(alignment: .firstTextBaseline) {
                        Image(systemName: "square.and.pencil").foregroundColor(.arcSelected)
                        Text("EDIT")
                            .font(.custom("Rubik-Medium", size: 12))
                            .foregroundColor(.arcSelected)
                            .kerning(1)
                    }
                }
            )
            .onAppear {
                self.selectedItems.items.removeAll()
                self.selectedItems.items.insert(self.timelineItem)
            }
    }

    func editView(for timelineItem: TimelineItem) -> AnyView {
        if let visit = timelineItem as? ArcVisit {
            return AnyView(VisitEditView(visit: visit, selectedItems: selectedItems, placeClassifier: visit.placeClassifier))
        }
        if let path = timelineItem as? ArcPath, let classifierResults = path.classifierResults {
            return AnyView(PathEditView(path: path, selectedItems: selectedItems, classifierResults: classifierResults))
        }
        return AnyView(EmptyView())
    }

}

//struct ItemDetailsView_Previews: PreviewProvider {
//    static var previews: some View {
//        ItemDetailsView()
//    }
//}
