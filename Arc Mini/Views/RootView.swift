//
//  RootView.swift
//  Arc Mini
//
//  Created by Matt Greenfield on 2/3/20.
//  Copyright © 2020 Matt Greenfield. All rights reserved.
//

import SwiftUI

struct RootView: View {

    var body: some View {
        GeometryReader { metrics in
            ZStack(alignment: .bottom) {
                MapView().edgesIgnoringSafeArea(.all)
                VStack {
                    TimelineView(segment: AppDelegate.todaySegment)
                        .frame(width: metrics.size.width, height: 400)
                }
            }
        }
    }
    
}

struct RootView_Previews: PreviewProvider {
    static var previews: some View {
        RootView()
    }
}
