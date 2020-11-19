//
//  SystemDebugView.swift
//  Arc Mini
//
//  Created by Matt Greenfield on 14/4/20.
//  Copyright © 2020 Matt Greenfield. All rights reserved.
//

import SwiftUI
import LocoKit

struct SystemDebugView: View {

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("General")) {
                    self.row(leftText: "Thermal state", right: Text(AppDelegate.thermalState.stringValue))
                    self.row(leftText: "Memory footprint", right: Text(AppDelegate.memoryString ?? "?"))
                }
                Section(header: Text("Task Queues")) {
                    self.row(leftText: "Primary queue jobs", right: Text("\(Jobs.highlander.primaryQueue.operationCount)"))
                    self.row(leftText: "Secondary queue jobs", right: Text("\(Jobs.highlander.secondaryQueue.operationCount)"))
                    NavigationLink(destination: PlacesPendingUpdateView()) {
                        self.row(leftText: "Places pending update", right: Text("\(RecordingManager.store.placesPendingUpdate)"))
                    }
                    NavigationLink(destination: ModelsPendingUpdateView()) {
                        self.row(leftText: "UD models pending update", right: Text("\(RecordingManager.store.modelsPendingUpdate)"))
                    }
                }
                Section(header: Text("Pending Backups")) {
                    self.row(leftText: "Notes pending backup", right: Text("\(Backups.backupNotesCount)"))
                    self.row(leftText: "Places pending backup", right: Text("\(Backups.backupPlacesCount)"))
                    self.row(leftText: "Timeline Summaries pending backup", right: Text("\(Backups.backupTimelineSummariesCount)"))
                    self.row(leftText: "Items pending backup", right: Text("\(Backups.backupItemsCount)"))
                    self.row(leftText: "Samples pending backup", right: Text("\(Backups.backupSamplesCount)"))
                }
                self.taskRows
            }
            .navigationBarTitle("Arc Mini \(Bundle.versionNumber) (\(String(format: "%d", Bundle.buildNumber)))")
            .environment(\.defaultMinListRowHeight, 28)
        }
    }

    // MARK: -

    var taskRows: some View {
        Section(header: Text("Task States")) {
            ForEach(TasksManager.highlander.taskStates.sorted { $0.value.lastUpdated > $1.value.lastUpdated }, id: \.0) { identifier, status in
                self.row(leftText: taskNameString(for: status, identifier: identifier), right: Text(statusString(for: status)))
            }
        }
    }

    // MARK: -

    func row(leftText: String, right rightText: Text) -> some View {
        return HStack {
            Text(leftText).font(.system(.footnote))
            Spacer()
            rightText.font(.system(.footnote)).opacity(0.6)
        }
    }
    
    func taskNameString(for task: TasksManager.TaskStatus, identifier: String) -> String {
        if task.state == .running {
            return "▶︎ " + identifier
        }
        if let lastCompleted = task.lastCompleted, (task.minimumDelay == 0 || lastCompleted.age < task.minimumDelay) {
            if task.state == .scheduled {
                return "✓ ▷ " + identifier
            }
            return "✓ " + identifier
        }
        if task.state == .scheduled {
            return "▷ " + identifier
        }
        return String(identifier)
    }
    
    func statusString(for task: TasksManager.TaskStatus) -> String {
        if task.state == .running { return "running" }
        if let lastCompleted = task.lastCompleted {
            return "completed \(String(duration: -lastCompleted.timeIntervalSinceNow, style: .short, maximumUnits: 1)) ago"
        }
        if task.state == .registered { return "registered" }
        return "\(task.state.rawValue) \(String(duration: -task.lastUpdated.timeIntervalSinceNow, style: .short, maximumUnits: 1)) ago"
    }

}
