//
//  DebugLogsView.swift
//  Arc Mini
//
//  Created by Matt Greenfield on 9/4/20.
//  Copyright © 2020 Matt Greenfield. All rights reserved.
//

import SwiftUI

struct DebugLogsView: View {

    @EnvironmentObject var debugLogger: DebugLogger

    var body: some View {
        NavigationView {
            List {
                ForEach(debugLogger.logFileURLs, id: \.absoluteString) { url in
                    NavigationLink(destination: DebugLogView(logURL: url)) {
                        Text((url.lastPathComponent as NSString).deletingPathExtension)
                    }
                }
                .onDelete(perform: delete)
            }
            .navigationBarTitle("Session Logs")
            .navigationBarItems(trailing: EditButton())
        }
    }

    func delete(at offsets: IndexSet) {
        for index in offsets {
            let url = debugLogger.logFileURLs[index]
            do {
                try debugLogger.delete(url)
            } catch {
                logger.error("Couldn't delete the log file.")
            }
        }
    }

}

struct DebugLogsView_Previews: PreviewProvider {
    static var previews: some View {
        DebugLogsView()
    }
}
