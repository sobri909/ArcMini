//
//  SystemDebugView.swift
//
//  Created by Matt Greenfield on 14/4/20.
//  Copyright © 2020 Matt Greenfield. All rights reserved.
//

import SwiftUI
import LocoKit

struct SystemDebugView: View {
    
    @State var refreshingSamplesPending = false
    @State var samplesPendingBackup: Int?
    @State var copyingDatabase = false

    var samplesPendingText: Text {
        if let count = samplesPendingBackup { return Text("\(count)") }
        return Text("?")
    }
    
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
                    if Backups.backupQueue.operationCount > 0 {
                        self.row(leftText: "Backup queue jobs", right: Text("\(Backups.backupQueue.operationCount)"))
                    }
                    if Backups.samplesBackupQueue.operationCount > 0 {
                        self.row(leftText: "Backup samples queue jobs", right: Text("\(Backups.samplesBackupQueue.operationCount)"))
                    }
                    NavigationLink(destination: PlacesPendingUpdateView()) {
                        self.row(leftText: "Places pending update", right: Text("\(RecordingManager.store.placesPendingUpdate)"))
                    }
                    .listRowInsets(EdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 10))
                    NavigationLink(destination: ModelsPendingUpdateView()) {
                        self.row(leftText: "CD2 models pending update", right: Text("\(RecordingManager.store.coreMLModelsPendingUpdate)"))
                    }
                    .listRowInsets(EdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 10))
                    NavigationLink(destination: ModelsPendingUpdateView()) {
                        self.row(leftText: "UD2 models pending update", right: Text("\(RecordingManager.store.modelsPendingUpdate)"))
                    }
                    .listRowInsets(EdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 10))
                }
                Section(header: Text("Pending Backups")) {
                    self.row(leftText: "Notes pending backup", right: Text("\(Backups.backupNotesCount)"))
                    self.row(leftText: "Places pending backup", right: Text("\(Backups.backupPlacesCount)"))
                    self.row(leftText: "Timeline Summaries pending backup", right: Text("\(Backups.backupTimelineSummariesCount)"))
                    self.row(leftText: "Items pending backup", right: Text("\(Backups.backupItemsCount)"))
                    self.row(leftText: "Samples pending backup", right: samplesPendingText, rightButtonText: Text("refresh"))
                        .opacity(refreshingSamplesPending ? 0.5 : 1)
                        .onTapGesture {
                            refreshingSamplesPending = true
                            Task {
                                samplesPendingBackup = Backups.backupSamplesCount
                                refreshingSamplesPending = false
                            }
                        }
                }

                taskRows
#if DEBUG || MERELEASE
                debugActionRows
#endif
            }
            .navigationBarTitle("Arc \(Bundle.versionNumber) (\(String(format: "%d", Bundle.buildNumber)))")
            .environment(\.defaultMinListRowHeight, 28)
        }
    }

    // MARK: -

    var taskRows: some View {
        Section(header: Text("Task States")) {
            let sortedStates = TasksManager.highlander.taskStates.sorted {
                if $0.value.state == $1.value.state {
                    return $0.value.lastCompleted ?? $0.value.lastUpdated - .oneYear > $1.value.lastCompleted ?? $0.value.lastUpdated - .oneYear
                } else {
                    return $0.value.state.sortIndex < $1.value.state.sortIndex
                }
            }.filter { !TasksManager.TaskIdentifier.deprecatedIdentifiers.contains($0.key) }

            ForEach(sortedStates, id: \.0) { identifier, status in
                self.row(leftText: taskNameString(for: status, identifier: identifier), right: Text(statusString(for: status)))
            }
        }
    }

    var debugActionRows: some View {
        Section(header: Text("Debug Actions")) {
            if copyingDatabase {
                Text("Copying database...")
                    .font(.system(size: 13, weight: .regular))
            } else {
                Button {
                    Task {
                        copyingDatabase = true
                        RecordingManager.store.copyDatabasesToLocal()
                        copyingDatabase = false
                    }
                } label: {
                    Text("Copy LocoKit database to app container")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(Color(uiColor: .link))
                }
            }
        }
    }

    // MARK: -

    func row(leftText: String, right rightText: Text, rightButtonText: Text? = nil) -> some View {
        return HStack {
            Text(leftText).font(.system(size: 12, weight: .regular))
            Spacer()
            rightText.font(.system(size: 12, weight: .regular)).opacity(0.6)
            if let rightButtonText = rightButtonText {
                rightButtonText.font(.system(size: 12, weight: .regular))
                    .padding([.leading, .trailing], 8)
                    .foregroundColor(.white).background(Color.black)
                    .cornerRadius(10)
            }
        }
        .frame(height: 28)
        .listRowInsets(EdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 10))
    }
    
    func taskNameString(for task: TasksManager.TaskStatus, identifier: String) -> String {
        if task.state == .expired {
            return "✕ " + identifier
        }
        if task.state == .unfinished {
            return "!! " + identifier
        }
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
