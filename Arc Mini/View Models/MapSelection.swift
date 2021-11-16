//
//  MapSelection.swift
//  Arc Mini
//
//  Created by Matt Greenfield on 16/11/21.
//  Copyright © 2021 Matt Greenfield. All rights reserved.
//

import Foundation

class MapSelection: ObservableObject {
    
    static let highlander = MapSelection()

    @Published var tappedSelectedItem = false
    var selectedTimelineItem: ArcTimelineItem?

}
