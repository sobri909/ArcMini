//
//  GeometryGetter.swift
//  Arc Mini
//
//  Created by Matt Greenfield on 21/3/20.
//  Copyright © 2020 Matt Greenfield. All rights reserved.
//

import SwiftUI
import LocoKit

// https://stackoverflow.com/a/56729880/790036
struct GeometryGetter: View {

    @Binding var rect: CGRect

    var body: some View {
        return GeometryReader { geometry in
            self.makeView(geometry: geometry)
        }
    }

    func makeView(geometry: GeometryProxy) -> some View {
        onMain {
            self.rect = geometry.frame(in: .global)
        }
        return Rectangle().fill(Color.clear)
    }

}
