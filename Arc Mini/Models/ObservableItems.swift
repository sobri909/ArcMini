//
//  ObservableItems.swift
//  Arc Mini
//
//  Created by Matt Greenfield on 20/3/20.
//  Copyright © 2020 Matt Greenfield. All rights reserved.
//

import Combine
import LocoKit

final class ObservableItems: ObservableObject {
    @Published var items: Set<TimelineItem> = []
}
