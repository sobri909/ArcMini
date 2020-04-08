//
//  PagerView.swift
//  Arc Mini
//
//  Created by Matt Greenfield on 3/4/20.
//  Copyright © 2020 Matt Greenfield. All rights reserved.
//

import SwiftUI

// https://swiftwithmajid.com/2019/12/25/building-pager-view-in-swiftui/

struct PagerView<Content: View>: View {

    @EnvironmentObject var timelineState: TimelineState

    let pageCount: Int
    let content: Content
    @Binding var currentIndex: Int
    @GestureState private var translation: CGFloat = 0

    init(pageCount: Int, currentIndex: Binding<Int>, @ViewBuilder content: () -> Content) {
        self.pageCount = pageCount
        self._currentIndex = currentIndex
        self.content = content()
    }

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                self.content.frame(width: geometry.size.width)
                    .background(Color("background"))
            }
            .frame(width: geometry.size.width, alignment: .leading)
            .offset(x: -CGFloat(self.currentIndex) * geometry.size.width)
            .offset(x: self.translation)
            .animation(.interactiveSpring())
            .gesture(
                DragGesture().updating(self.$translation) { value, state, _ in
                    state = value.translation.width
                }.onEnded { value in
                    let offset = value.translation.width / geometry.size.width
                    let newIndex = (CGFloat(self.currentIndex) - offset).rounded()
                    self.currentIndex = min(max(Int(newIndex), 0), self.pageCount - 1)
                }
            )
        }
    }
    
}
