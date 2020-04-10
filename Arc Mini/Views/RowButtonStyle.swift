//
//  RowButtonStyle.swift
//  Arc Mini
//
//  Created by Matt Greenfield on 29/3/20.
//  Copyright © 2020 Matt Greenfield. All rights reserved.
//

import SwiftUI

struct RowButtonStyle: ButtonStyle {
    func makeBody(configuration: RowButtonStyle.Configuration) -> some View {
        configuration.label.background(configuration.isPressed ? Color(UIColor.arcGray1) : Color("background"))
    }
}
