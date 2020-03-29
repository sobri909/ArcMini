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

    var path: ArcPath
    
    var body: some View {
        ZStack {
            HStack {
                Rectangle().fill(path.color).frame(width: 3).cornerRadius(1.5)
                Spacer().frame(width: 34)
                VStack(alignment: .leading) {
                    Text(path.title).font(.system(size: 14, weight: .medium))
                    Text(String(duration: path.duration)).font(.system(size: 14, weight: .regular))
                }
                Spacer()
            }
            .padding([.leading], 102)
            .padding([.trailing], 20)
            .contextMenu {
                NavigationLink(destination: PathEditView(path: path, classifierResults: path.classifierResults!)) {
                    Text("Edit trip")
                    Image(systemName: "square.and.pencil")
                }
                NavigationLink(destination: SegmentsEditView(timelineItem: path)) {
                    Text("Edit individual segments")
                    Image(systemName: "ellipsis")
                }
            }
        }
    }

}

//struct PathListBox_Previews: PreviewProvider {
//    static var previews: some View {
//        PathListBox()
//    }
//}
