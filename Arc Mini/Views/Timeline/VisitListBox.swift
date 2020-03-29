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

    var visit: ArcVisit

    var body: some View {
        VStack {
            HStack(alignment: .top, spacing: 0) {
                VStack(alignment: .leading) {
                    if visit.dateRange != nil {
                        Text(visit.startTimeString!)
                            .frame(width: 72, alignment: .leading)
                            .font(.system(size: 16, weight: .medium))
                        Text(String(duration: visit.dateRange!.duration, style: .abbreviated))
                            .frame(width: 72, alignment: .leading)
                            .font(.system(size: 13, weight: .regular))
                    }
                }
                Image("defaultPlaceIcon24")
                Spacer().frame(width: 24)
                Text(visit.title).font(.system(size: 16, weight: .semibold))
                Spacer()
            }
            .padding([.leading, .trailing], 20)
            .contextMenu {
                NavigationLink(destination: VisitEditView(visit: visit, placeClassifier: visit.placeClassifier)) {
                    Text("Edit visit")
                    Image(systemName: "square.and.pencil")
                }
                if !visit.isCurrentItem {
                    Button(action: {
                        // TODO
                    }) {
                        Text("Delete visit")
                        Image(systemName: "trash")
                    }
                    .foregroundColor(.red)
                }
                NavigationLink(destination: SegmentsEditView(timelineItem: visit)) {
                    Text("Edit individual segments")
                    Image(systemName: "ellipsis")
                }
            }
        }
    }
    
}

//struct VisitListBox_Previews: PreviewProvider {
//    static var previews: some View {
//        VisitListBox()
//    }
//}
