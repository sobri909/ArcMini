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

        let appearance = UINavigationBarAppearance()
        appearance.setBackIndicatorImage(UIImage(systemName: "arrow.left"), transitionMaskImage: nil)
        UINavigationBar.appearance().standardAppearance = appearance
    }

    var body: some View {
        Text((timelineItem as! ArcTimelineItem).title)
            .introspectNavigationController { nav in
                nav.setNavigationBarHidden(false, animated: true)
                nav.navigationBar.tintColor = .arcSelected
                nav.navigationBar.backIndicatorImage = UIImage(systemName: "arrow.left")
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
        if let path = timelineItem as? ArcPath {
            return AnyView(PathEditView(path: path))
        }
        fatalError("nah")
    }

}

//struct ItemDetailsView_Previews: PreviewProvider {
//    static var previews: some View {
//        ItemDetailsView()
//    }
//}
