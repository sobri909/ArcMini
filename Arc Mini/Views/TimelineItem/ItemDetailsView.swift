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

    @State var tappedEditButton = false

    init(timelineItem: TimelineItem) {
        self.timelineItem = timelineItem
    }

    var body: some View {
        List {
            Text((timelineItem as! ArcTimelineItem).title)
                .font(.custom("SofiaProBold", size: 22))
                .foregroundColor(Color("brandTertiaryDark"))
                .padding(.top, 24)
            HStack {
                Spacer()
                self.editButton
            }.padding(.trailing, 14)
        }
        .navigationBarHidden(true)
        .navigationBarTitle("", displayMode: .inline)
        .onAppear {
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

    var editButton: some View {
        ZStack(alignment: .trailing) {
            Button(action: {
                self.tappedEditButton = true
            }) {
                HStack(alignment: .center) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color("brandSecondary80"))
                        .offset(x: 0, y: -1)
                    Text("Edit")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Color("brandSecondaryDark"))
                }
            }
            .frame(height: 50)
            NavigationLink(destination: editView(for: timelineItem), isActive: $tappedEditButton) {
                EmptyView()
            }
        }
    }

    func editView(for timelineItem: TimelineItem) -> AnyView {
        if let visit = timelineItem as? ArcVisit {
            return AnyView(VisitEditView(visit: visit, placeClassifier: visit.placeClassifier))
        }
        if let path = timelineItem as? ArcPath {
            return AnyView(PathEditView(path: path))
        }
        return AnyView(EmptyView())
    }

}

//struct ItemDetailsView_Previews: PreviewProvider {
//    static var previews: some View {
//        ItemDetailsView()
//    }
//}
