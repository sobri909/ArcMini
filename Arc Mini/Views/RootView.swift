//
//  RootView.swift
//  Arc Mini
//
//  Created by Matt Greenfield on 2/3/20.
//  Copyright © 2020 Matt Greenfield. All rights reserved.
//

import SwiftUI
import LocoKit

struct RootView: View {

    @ObservedObject var todaySegment: TimelineSegment
    @EnvironmentObject var mapState: MapState

    var body: some View {
        GeometryReader { metrics in
            ZStack(alignment: .bottom) {
                MapView(segment: self.todaySegment, mapState: self.mapState)
                    .edgesIgnoringSafeArea(.all)
                VStack {
                    TimelineView(segment: self.todaySegment)
                        .frame(width: metrics.size.width, height: 400)
                }
            }
        }
    }
    
}

//struct RootView_Previews: PreviewProvider {
//    static var previews: some View {
//        RootView()
//    }
//}

