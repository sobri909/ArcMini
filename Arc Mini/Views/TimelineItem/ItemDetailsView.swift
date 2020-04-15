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

    var arcItem: ArcTimelineItem { return timelineItem as! ArcTimelineItem }

    // MARK: -

    init(timelineItem: TimelineItem) {
        self.timelineItem = timelineItem
    }

    // MARK: -

    var body: some View {
        List {
            VStack(alignment: .leading) {
                Spacer().frame(height: 24)
                Text(arcItem.title)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(Color("brandTertiaryDark"))
                    .frame(height: 28)
                Spacer().frame(height: 2)
                Text(self.dateRangeString)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color("brandTertiaryLight"))
                    .frame(height: 26)
            }
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

    var dateRangeString: String {
        guard let dateRange = timelineItem.dateRange else { return "" }
        guard let startString = arcItem.startTimeString else { return "" }

        if dateRange.start.isToday, let endString = arcItem.endTimeString {
            return String(format: "%@ · %@ - %@", dateRange.shortDurationString, startString, endString)
        }

        if let endDateString = arcItem.startString(dateStyle: .long, timeStyle: .none, relative: true) {
            return String(format: "%@ · %@, %@", dateRange.shortDurationString, startString, endDateString)
        }

        return ""
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
