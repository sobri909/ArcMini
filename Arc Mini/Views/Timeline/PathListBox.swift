//
//  PathListBox.swift
//  Arc Mini
//
//  Created by Matt Greenfield on 10/3/20.
//  Copyright © 2020 Matt Greenfield. All rights reserved.
//

import SwiftUI
import LocoKit

struct PathListBox: View {

    @ObservedObject var path: ArcPath
    @State var openDetailsView = false
    @State var openEditView = false
    @State var openSegmentsView = false
    
    var body: some View {
        ZStack {
            NavigationLink(destination: ItemDetailsView(timelineItem: path), isActive: $openDetailsView) {}
            NavigationLink(destination: PathEditView(path: path), isActive: $openEditView) {}
            NavigationLink(destination: ItemSegmentsView(timelineItem: path), isActive: $openSegmentsView) {}
            Button {
                openDetailsView = true
            } label: {
                HStack {
                    Rectangle().fill(path.color).frame(width: 3).cornerRadius(1.5)
                    Spacer().frame(width: 34)
                    VStack(alignment: .leading) {
                        Text(title).font(.system(size: 14, weight: .medium))
                        Text(String(duration: path.duration)).font(.system(size: 14, weight: .regular))
                    }
                    Spacer()
                }
            }
            .frame(height: 44)
            .padding([.leading], 102)
            .padding([.trailing], 20)
            .background(Color("background"))
            .onAppear {
                openDetailsView = false
                openEditView = false
                openSegmentsView = false
            }
            .contextMenu {
                Button {
                    openEditView = true
                } label: {
                    Text("Edit trip")
                    Image(systemName: "square.and.pencil")
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

    var title: String {
        var debug = ""
        if path.hasBrokenNextItemEdge { debug += "↑" }
        if path.hasBrokenPreviousItemEdge { debug += "↓" }
        return debug + path.title
    }

}
