//
//  WidgetState.swift
//  Arc Mini
//
//  Created by Matt Greenfield on 28/6/20.
//  Copyright © 2020 Matt Greenfield. All rights reserved.
//

import SwiftUI
import LocoKit

class WidgetState: ObservableObject {
    var appGroup = AppGroup(appName: .arcMini, suiteName: "group.ArcApp")
}
