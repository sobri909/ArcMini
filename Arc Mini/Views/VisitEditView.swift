//
//  VisitEditView.swift
//  Arc Mini
//
//  Created by Matt Greenfield on 22/3/20.
//  Copyright © 2020 Matt Greenfield. All rights reserved.
//

import SwiftUI
import LocoKit

struct VisitEditView: View {

    var visit: ArcVisit
    @ObservedObject var selectedItems: ObservableItems
    @ObservedObject var placeClassifier: PlaceClassifier

    var body: some View {
        List {
            ForEach(placeClassifier.results, id: \.place.placeId) { result in
                Button(action: {
                    self.visit.usePlace(result.place, manualPlace: true)
                }) {
                    if self.visit.place == result.place {
                        Text(result.place.name)
                            .font(.system(size: 17, weight: .semibold))
                    } else {
                        Text(result.place.name)
                            .font(.system(size: 17, weight: .regular))
                    }
                }
            }
        }
        .onAppear {
            self.selectedItems.items.removeAll()
            self.selectedItems.items.insert(self.visit)
            self.placeClassifier.results()
            self.fetchPlaces()
        }
    }

    // MARK: - Search

    func fetchPlaces() {
        placeClassifier.fetchRemotePlaces().done {
            self.placeClassifier.results()
        }.cauterize()
    }

}

//struct VisitEditView_Previews: PreviewProvider {
//    static var previews: some View {
//        VisitEditView()
//    }
//}
