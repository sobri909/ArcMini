//
//  TimelineRootView.swift
//  Arc Mini
//
//  Created by Matt Greenfield on 6/4/20.
//  Copyright © 2020 Matt Greenfield. All rights reserved.
//

import SwiftUI

struct TimelineRootView: View {

    @EnvironmentObject var timelineState: TimelineState

    var body: some View {
        VStack(spacing: 0) {
            TimelineHeader()
            TimelineScrollView()
        }
    }
}

struct TimelineRootView_Previews: PreviewProvider {
    static var previews: some View {
        TimelineRootView()
    }
}
