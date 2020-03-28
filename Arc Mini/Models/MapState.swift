//
//  MapState.swift
//  Arc Mini
//
//  Created by Matt Greenfield on 28/3/20.
//  Copyright © 2020 Matt Greenfield. All rights reserved.
//

import LocoKit

class MapState: ObservableObject {
    @Published var selectedItems: Set<TimelineItem> = []
}
