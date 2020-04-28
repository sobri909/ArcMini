//
//  VisitEditView.swift
//  Arc Mini
//
//  Created by Matt Greenfield on 22/3/20.
//  Copyright © 2020 Matt Greenfield. All rights reserved.
//

import SwiftUI
import LocoKit
import CoreLocation

struct VisitEditView: View {

    @EnvironmentObject var mapState: MapState
    @EnvironmentObject var timelineState: TimelineState
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>

    @ObservedObject var visit: ArcVisit
    @ObservedObject var placeClassifier: PlaceClassifier

    init(visit: ArcVisit, placeClassifier: PlaceClassifier) {
        self.visit = visit
        self.placeClassifier = placeClassifier
        UITableViewCell.appearance().selectionStyle = .default
    }

    var body: some View {
        VStack {
            List {
                ItemDetailsHeader(timelineItem: self.visit)
                ForEach(placeClassifier.results, id: \.place.placeId) { result in
                    Button(action: {
                        self.visit.usePlace(result.place, manualPlace: true)
                        self.presentationMode.wrappedValue.dismiss()
                    }) {
                        HStack {
                            result.place.categoryImage.renderingMode(.template).foregroundColor(Color("brandSecondary80"))
                            Spacer().frame(width: 20)
                            if self.visit.place == result.place {
                                Text(result.place.name)
                                    .font(.system(size: 17, weight: .semibold))
                            } else {
                                Text(result.place.name)
                                    .font(.system(size: 17, weight: .regular))
                            }
                            Spacer()
                            Text(self.rightText(for: result.place))
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(Color(UIColor.arcGray1))
                        }
                    }
                    .padding([.leading, .trailing], 20)
                    .frame(height: 44)
                    .listRowInsets(EdgeInsets())
                    .background(Color("background"))
                }
            }
            .environment(\.defaultMinListRowHeight, 44)
        }
        .navigationBarHidden(true)
        .navigationBarTitle("", displayMode: .inline)
        .onAppear {
            self.mapState.selectedItems = [self.visit]
            self.mapState.itemSegments = self.visit.segmentsByActivityType
            self.timelineState.backButtonHidden = false
            self.timelineState.todayButtonHidden = true
            self.placeClassifier.results()
            self.fetchPlaces()
        }
        .onReceive(self.timelineState.$tappedBackButton) { tappedBackButton in
            if tappedBackButton {
                self.presentationMode.wrappedValue.dismiss()
                self.timelineState.tappedBackButton = false
            }
        }
    }

    func rightText(for place: Place) -> String {
        guard let distanceAway = place.edgeToEdgeDistanceFrom(visit) else { return "" }
        return distanceAway < 2 ? "" : String(metres: distanceAway, style: .medium)
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
