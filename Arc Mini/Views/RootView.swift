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

    @EnvironmentObject var timelineState: TimelineState
    @EnvironmentObject var mapState: MapState

    var body: some View {
        GeometryReader { metrics in
            ZStack(alignment: .bottom) {
                MapView(mapState: self.mapState, timelineState: self.timelineState)
                    .edgesIgnoringSafeArea(.all)
                VStack(spacing: 0) {
                    NavBar()
                    Spacer()
                    NavigationView {
                        TimelineRootView()
                    }
                    .frame(width: metrics.size.width, height: metrics.size.height * self.timelineState.bodyHeightPercent)
                    .background(Color("background"))
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

