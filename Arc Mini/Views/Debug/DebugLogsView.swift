//
//  DebugLogsView.swift
//  Arc Mini
//
//  Created by Matt Greenfield on 9/4/20.
//  Copyright © 2020 Matt Greenfield. All rights reserved.
//

import SwiftUI

struct DebugLogsView: View {
    var body: some View {
        NavigationView {
            List {
                ForEach(DebugLogger.highlander.logFileURLs, id: \.absoluteString) { url in
                    NavigationLink(destination: DebugLogView(logURL: url)) {
                        Text(url.lastPathComponent)
                    }
                }
            }
            .navigationBarTitle("Session Logs")
        }
    }
}

struct DebugLogsView_Previews: PreviewProvider {
    static var previews: some View {
        DebugLogsView()
    }
}
