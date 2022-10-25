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
            .toolbar {
                deleteAllButton
            }
        }
    }

    func rightText(for url: URL) -> String {
        guard let duration = duration(for: url) else { return "" }
        return String(duration: duration, style: .abbreviated, maximumUnits: 2)
    }

    func duration(for url: URL) -> TimeInterval? {
        guard let resourceValues = try? url.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey]) else { return nil }
        guard let created = resourceValues.creationDate else { return nil }
        guard let modified = resourceValues.contentModificationDate else { return nil }
        return modified.timeIntervalSince(created)
    }

    var deleteAllButton: some View {
        Button {
            deleteAll()
        } label: {
            Text("Delete all")
        }
    }

    // MARK: - Actions

    func deleteAll() {
        for url in debugLogger.logFileURLs {

            // can't delete the current session log file
            if url.lastPathComponent == DebugLogger.highlander.sessionLogFileURL.lastPathComponent { continue }

            do {
                try debugLogger.delete(url)
            } catch {
                logger.error("Couldn't delete the log file.")
            }
        }
    }

    func delete(at offsets: IndexSet) {
        for index in offsets {
            let url = debugLogger.logFileURLs[index]

            // can't delete the current session log file
            if url.lastPathComponent == DebugLogger.highlander.sessionLogFileURL.lastPathComponent { continue }

            do {
                try debugLogger.delete(url)
            } catch {
                logger.error("Couldn't delete the log file.")
            }
        }
    }

}
