//
//  VisitListBox.swift
//  Arc Mini
//
//  Created by Matt Greenfield on 10/3/20.
//  Copyright © 2020 Matt Greenfield. All rights reserved.
//

import SwiftUI
import LocoKit

struct VisitListBox: View {

    @EnvironmentObject var timelineState: TimelineState
    @ObservedObject var visit: ArcVisit
    @State var showDeleteAlert = false
    @State var openEditView = false
    @State var openSegmentsView = false

    var body: some View {
        ZStack {
            NavigationLink(destination: VisitEditView(visit: visit, placeClassifier: visit.placeClassifier), isActive: $openEditView) {}
            NavigationLink(destination: ItemSegmentsView(timelineItem: visit), isActive: $openSegmentsView) {}
            VStack {
                HStack(alignment: .top, spacing: 0) {
                    Button {
                        timelineState.showStartEndDates.toggle()
                    } label: {
                        VStack(alignment: .leading) {
                            if timelineState.showStartEndDates {
                                Text(visit.endTimeString ?? "")
                                    .frame(width: 72, alignment: .leading)
                                    .font(.system(size: 16, weight: .medium))
                                    .frame(height: 17)
                            }
                            Text(visit.startTimeString ?? "")
                                .frame(width: 72, alignment: .leading)
                                .font(.system(size: 16, weight: .medium))
                                .frame(height: 17)
                            Text(String(duration: visit.duration, style: .abbreviated))
                                .frame(width: 72, alignment: .leading)
                                .font(.system(size: 13, weight: .regular))
                        }
                    }.buttonStyle(.plain)
                    self.categoryImage.renderingMode(.template).foregroundColor(self.categoryColor)
                    Spacer().frame(width: 24)
                    Text(title).font(.system(size: 16, weight: .semibold))
                    Spacer()
                }
                .padding(EdgeInsets(top: 14, leading: 20, bottom: 14, trailing: 20))
                .background(Color("background"))
                .contextMenu {
                    Button {
                        openEditView = true
                    } label: {
                        Text("Edit visit")
                        Image(systemName: "square.and.pencil")
                    }
                    if !visit.isCurrentItem {
                        Button {
                            self.showDeleteAlert = true
                        } label: {
                            Text("Delete visit")
                            Image(systemName: "trash")
                        }
                        .foregroundColor(.red)
                        .alert(isPresented: $showDeleteAlert) {
                            Alert.delete(visit: self.visit)
                        }
                    }
                    Button {
                        openSegmentsView = true
                    } label: {
                        Text("Edit individual segments")
                        Image(systemName: "ellipsis")
                    }
                }
            }
        }
    }

    var title: String {
        var debug = ""
        if visit.hasBrokenNextItemEdge { debug += "↑" }
        if visit.hasBrokenPreviousItemEdge { debug += "↓" }
        return debug + visit.title
    }

    var categoryImage: Image {
        if let image = visit.place?.categoryImage { return image }
        return Image("defaultPlaceIcon24")
    }

    var categoryColor: Color {
        if let prev = visit.previousItem as? ArcPath, let dateRange = visit.dateRange, dateRange.start.isSameDayAs(dateRange.end) {
            return prev.color
        }
        if let next = visit.nextItem as? ArcPath { return next.color }
        return Color(UIColor.arcGreen)
    }

}

//struct VisitListBox_Previews: PreviewProvider {
//    static var previews: some View {
//        VisitListBox()
//    }
//}
