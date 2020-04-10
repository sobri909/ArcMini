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
                        HStack {
                            Text((url.lastPathComponent as NSString).deletingPathExtension)
                            Spacer()
                            Text(self.rightText(for: url))
                        }
                    }
                }
                .onDelete(perform: delete)
            }
            .navigationBarTitle("Session Logs")
            .navigationBarItems(trailing: EditButton())
        }
    }

    func rightText(for url: URL) -> String {
        guard let duration = duration(for: url) else { return "" }
        return String(duration: duration, style: .abbreviated, maximumUnits: 1)
    }

    func duration(for url: URL) -> TimeInterval? {
        guard let resourceValues = try? url.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey]) else { return nil }
        guard let created = resourceValues.creationDate else { return nil }
        guard let modified = resourceValues.contentModificationDate else { return nil }
        return modified.timeIntervalSince(created)
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
