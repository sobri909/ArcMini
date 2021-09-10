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
    
    @EnvironmentObject var mapState: MapState

    var body: some View {
        GeometryReader { metrics in
            ZStack(alignment: .bottom) {
                MapView(mapState: self.mapState, timelineState: TimelineState.highlander)
                    .edgesIgnoringSafeArea(.all)
                VStack(spacing: 0) {
                    NavBar()
                    Spacer()
                    HStack {
                        Spacer()
                        self.fullMapButton
                            .offset(x: 0, y: self.mapState.showingFullMap ? self.timelineHeight(for: metrics, includingSafeArea: false) : 0)
                    }
                    NavigationView {
                        TimelineRootView()
                    }
                    .frame(width: metrics.size.width, height: self.timelineHeight(for: metrics))
                    .offset(x: 0, y: self.mapState.showingFullMap ? self.timelineHeight(for: metrics, includingSafeArea: true) : 0)
                }
            }
        }
    }

    func timelineHeight(for metrics: GeometryProxy, includingSafeArea: Bool = false) -> CGFloat {
        let height = metrics.size.height * TimelineState.highlander.bodyHeightPercent
        return includingSafeArea ? height + metrics.safeAreaInsets.bottom : height
    }

    var fullMapButton: some View {
        Button {
            withAnimation(.spring()) {
                MapState.highlander.showingFullMap.toggle()
            }
        } label: {
            Image(systemName: self.mapState.showingFullMap ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color("brandSecondaryBase").opacity(0.4))
                .frame(width: 40, height: 32)
                .background(Color("background").opacity(0.88))
                .cornerRadius(6)
                .shadow(color: Color.black.opacity(0.08), radius: 3, x: 0, y: 1)
        }
        .frame(width: 80, height: 62)
    }
    
}

