//
//  MiniStore.swift
//  CurrentItemWidgetExtension
//
//  Created by Matt Greenfield on 15/9/20.
//  Copyright © 2020 Matt Greenfield. All rights reserved.
//

import Foundation
import LocoKit

final class MiniStore: TimelineStore {
    override var dbDir: URL { get { return arcDbDir } set {} }

    lazy var arcDbDir: URL = {
        if let groupDir = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.ArcApp") { return groupDir }
        return try! FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
    }()
}
