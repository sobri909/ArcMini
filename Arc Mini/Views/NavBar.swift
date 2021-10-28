//
//  NavBar.swift
//  Arc Mini
//
//  Created by Matt Greenfield on 5/4/20.
//  Copyright © 2020 Matt Greenfield. All rights reserved.
//

import SwiftUI

struct NavBar: View {

    @EnvironmentObject var timelineState: TimelineState
    @EnvironmentObject var mapState: MapState

    var backButtonHidden: Bool {
        if mapState.showingFullMap { return true }
        return timelineState.backButtonHidden
    }
    
    var todayButtonHidden: Bool {
        if mapState.showingFullMap { return true }
        return timelineState.todayButtonHidden
    }
    
    var body: some View {
        HStack {
            backButton.opacity(backButtonHidden ? 0 : 1)
            Spacer()
            todayButton.opacity(todayButtonHidden ? 0 : 1)
        }.padding(.top, 4)
    }

    var backButton: some View {
        Button {
            timelineState.tappedBackButton = true
        } label: {
            Image(systemName: "chevron.left")
                .foregroundColor(.white)
                .frame(width: 40, height: 40)
                .background(Color.black.opacity(0.38))
                .cornerRadius(20)
        }
        .frame(width: 56, height: 56)
    }

    var todayButton: some View {
        Button {
            timelineState.goto(date: Date())
        } label: {
            Image(systemName: "chevron.right.2")
                .foregroundColor(.white)
                .frame(width: 40, height: 40)
                .background(Color.black.opacity(0.38))
                .cornerRadius(20)
        }
        .frame(width: 56, height: 56)
    }

}
