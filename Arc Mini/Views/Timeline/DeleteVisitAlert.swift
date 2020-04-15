//
//  DeleteVisitAlert.swift
//  Arc Mini
//
//  Created by Matt Greenfield on 15/4/20.
//  Copyright © 2020 Matt Greenfield. All rights reserved.
//

import SwiftUI
import LocoKit

extension Alert {
    static func delete(visit: ArcVisit) -> Alert {
        return Alert(
            title: Text("Delete this visit?"),
            message: Text("The visit will be merged into the previous or following timeline item.\n\n"
                + "If you change your mind, you can revert the change from that item's Individual Segments view."),
            primaryButton: .destructive(Text("Delete"), action: {
                TimelineProcessor.safeDelete(visit)
            }),
            secondaryButton: .cancel()
        )
    }
}
