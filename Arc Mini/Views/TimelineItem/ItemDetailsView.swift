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
    @State var tappedSegmentsButton = false
    @State var showDeleteAlert = false

    var arcItem: ArcTimelineItem { return timelineItem as! ArcTimelineItem }

    // MARK: -

    init(timelineItem: TimelineItem) {
        self.timelineItem = timelineItem
    }

    // MARK: -

    var body: some View {
        ScrollView {
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
                    self.deleteButton.opacity(self.canDelete ? 1 : 0)
                    self.editButton
                }
            }
        }
        .background(Color("background"))
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

    var canDelete: Bool {
        guard timelineItem is ArcVisit else { return false }
        return !timelineItem.isCurrentItem
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
