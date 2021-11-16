//
//  MapState.swift
//  Arc Mini
//
//  Created by Matt Greenfield on 28/3/20.
//  Copyright © 2020 Matt Greenfield. All rights reserved.
//

import LocoKit
import SwiftUI

class MapState: ObservableObject {
    
    static let highlander = MapState()
    
    @Published var selectedItems: Set<TimelineItem> = []
    @Published var selectedSegments: Array<ItemSegment> = []
    @Published var itemSegments: Array<ItemSegment> = []
    @Published var showingFullMap = false

    func flush() {
        selectedItems = []
        itemSegments = []
    }
}
