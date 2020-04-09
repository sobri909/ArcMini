//
//  DebugLogView.swift
//  Arc Mini
//
//  Created by Matt Greenfield on 9/4/20.
//  Copyright © 2020 Matt Greenfield. All rights reserved.
//

import SwiftUI

struct DebugLogView: View {

    var logURL: URL

    var body: some View {
        ScrollView {
            Text(logText)
        }
        .navigationBarTitle(LocalizedStringKey(logURL.lastPathComponent), displayMode: .inline)
    }

    var logText: String {
        if let logString = try? String(contentsOf: logURL), !logString.isEmpty {
            return logString
        }
        return "Empty."
    }
}

//struct DebugLogView_Previews: PreviewProvider {
//    static var previews: some View {
//        DebugLogView()
//    }
//}
