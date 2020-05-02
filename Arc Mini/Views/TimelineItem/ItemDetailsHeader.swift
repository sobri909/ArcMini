//
//  ItemDetailsHeader.swift
//  Arc Mini
//
//  Created by Matt Greenfield on 28/4/20.
//  Copyright © 2020 Matt Greenfield. All rights reserved.
//

import SwiftUI
import LocoKit

struct ItemDetailsHeader: View {

    @ObservedObject var timelineItem: TimelineItem
    var arcItem: ArcTimelineItem { return timelineItem as! ArcTimelineItem }

    @State var tappedSegmentsButton = false
    @State var tappedEditButton = false
    @State var showDeleteAlert = false

    var body: some View {
        VStack(alignment: .leading) {
            Spacer().frame(height: 24)
            Text(arcItem.title)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(Color("brandTertiaryDark"))
                .padding([.leading, .trailing], 20)
                .frame(height: 28)
            Spacer().frame(height: 2)
            Text(self.dateRangeString)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Color("brandTertiaryLight"))
                .padding([.leading, .trailing], 20)
                .frame(height: 26)
            HStack(spacing: 0) {
                self.segmentsButton
                Spacer()
                if self.canDelete {
                    self.deleteButton
                }
                self.editButton
            }
            Rectangle().fill(Color("brandSecondary10")).frame(height: 0.5)
            Spacer().frame(height: 20)
        }
        .listRowInsets(EdgeInsets())
        .background(Color("background"))
    }

    // MARK: -

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

    var canDelete: Bool {
        guard timelineItem is ArcVisit else { return false }
        return !timelineItem.isCurrentItem
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

    // MARK: - Buttons

    var segmentsButton: some View {
        ZStack(alignment: .leading) {
            Button(action: {
                self.tappedSegmentsButton = true
            }) {
                HStack(alignment: .center) {
                    Image(systemName: "circle.grid.2x2")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundColor(Color("brandSecondary80"))
                        .frame(width: 24, height: 24)
                    Text("Segments")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(Color("brandSecondaryDark"))
                }.padding(.leading, 20)
            }
            .frame(height: 64)
            NavigationLink(destination: ItemSegmentsView(timelineItem: timelineItem), isActive: $tappedSegmentsButton) {
                EmptyView()
            }.hidden()
        }
    }

    var deleteButton: some View {
        ZStack(alignment: .trailing) {
            Button(action: {
                self.showDeleteAlert = true
            }) {
                HStack(alignment: .center) {
                    Spacer().frame(width: 20)
                    Image(systemName: "trash")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundColor(Color("brandSecondary80"))
                        .frame(width: 24, height: 24)
                        .offset(x: 0, y: -1)
                    Spacer().frame(width: 20)
                    Rectangle().fill(Color("grey")).frame(width: 1, height: 24)
                }
            }
            .frame(height: 64)
        }
        .alert(isPresented: $showDeleteAlert) {
            Alert.delete(visit: self.timelineItem as! ArcVisit)
        }
    }

    var editButton: some View {
        ZStack(alignment: .trailing) {
            Button(action: {
                self.tappedEditButton = true
            }) {
                HStack(alignment: .center) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundColor(Color("brandSecondary80"))
                        .frame(width: 24, height: 24)
                        .offset(x: 0, y: -1.5)
                    Text("Edit")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(Color("brandSecondaryDark"))
                }
                .padding([.leading, .trailing], 20)
            }
            .frame(height: 64)
            NavigationLink(destination: editView(for: timelineItem), isActive: $tappedEditButton) {
                EmptyView()
            }.hidden()
        }
    }

}

//struct ItemDetailsHeader_Previews: PreviewProvider {
//    static var previews: some View {
//        ItemDetailsHeader()
//    }
//}
