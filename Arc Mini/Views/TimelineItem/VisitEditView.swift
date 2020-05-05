//
//  VisitEditView.swift
//  Arc Mini
//
//  Created by Matt Greenfield on 22/3/20.
//  Copyright © 2020 Matt Greenfield. All rights reserved.
//

import LocoKit
import SwiftUI
import Combine
import CoreLocation

extension UIApplication {
    func endEditing(_ force: Bool) {
        self.windows.filter{ $0.isKeyWindow }.first?.endEditing(force)
    }
}

struct ResignKeyboardOnDragGesture: ViewModifier {
    var gesture = DragGesture().onChanged{_ in
        UIApplication.shared.endEditing(true)
    }
    func body(content: Content) -> some View {
        content.gesture(gesture)
    }
}

extension View {
    func resignKeyboardOnDragGesture() -> some View {
        return modifier(ResignKeyboardOnDragGesture())
    }
}

struct VisitEditView: View {

    @EnvironmentObject var mapState: MapState
    @EnvironmentObject var timelineState: TimelineState
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>

    @ObservedObject var visit: ArcVisit
    @ObservedObject var placeClassifier: PlaceClassifier

    @State var searchTextEditing = false

    init(visit: ArcVisit, placeClassifier: PlaceClassifier) {
        self.visit = visit
        self.placeClassifier = placeClassifier
        UITableViewCell.appearance().selectionStyle = .default
    }

    var body: some View {
        List {
            if placeClassifier.query.isEmpty && !searchTextEditing {
                ItemDetailsHeader(timelineItem: self.visit, includeEditButton: false)
            } else {
                Spacer().frame(height: 24).listRowInsets(EdgeInsets()).background(Color("background"))
            }
            VStack {
                HStack {
                    Image(systemName: "magnifyingglass")
                    TextField("Search nearby places", text: $placeClassifier.query, onEditingChanged: { isEditing in
                        self.searchTextEditing = isEditing
                    }, onCommit: {
                        print("onCommit")
                    }).foregroundColor(Color("brandTertiaryBase"))
                    Spacer().frame(width: 8)
                    Button(action: {
                        self.placeClassifier.query = ""
                    }) {
                        Image(systemName: "xmark.circle.fill").opacity(self.placeClassifier.query.isEmpty ? 0 : 1)
                    }
                }
                .padding([.leading, .trailing], 12)
                .frame(height: 40)
                .foregroundColor(Color("brandTertiaryBase"))
                .background(Color("brandSecondary05"))
                .cornerRadius(8)
                Spacer().frame(height: 20)
            }
            .padding([.leading, .trailing], 20)
            .listRowInsets(EdgeInsets())
            .background(Color("background"))

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
        .environment(\.defaultMinListRowHeight, 0)
        .navigationBarHidden(true)
        .navigationBarTitle("", displayMode: .inline)
        .resignKeyboardOnDragGesture()
        .onAppear {
            if self.visit.deleted {
                self.presentationMode.wrappedValue.dismiss()
                return
            }
            self.mapState.selectedItems = [self.visit]
            self.mapState.itemSegments = self.visit.segmentsByActivityType
            self.timelineState.backButtonHidden = false
            self.timelineState.todayButtonHidden = true
            self.placeClassifier.updateResults()
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

}

//struct VisitEditView_Previews: PreviewProvider {
//    static var previews: some View {
//        VisitEditView()
//    }
//}
