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
    @State var selectedTask: TasksManager.TaskStatus?

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
                backupRows
                taskRows
#if DEBUG || MERELEASE
                debugActionRows
#endif
            }
            .navigationBarTitle("Arc \(Bundle.versionNumber) (\(String(format: "%d", Bundle.buildNumber)))")
            .environment(\.defaultMinListRowHeight, 28)
            .sheet(item: $selectedTask) { item in
                if #available(iOS 16.0, *) {
                    taskDetails(for: item)
                        .presentationDetents([.height(240)])
                } else {
                    taskDetails(for: item)
                }
            }
        }
    }

    // MARK: -

    var backupRows: some View {
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
    }

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
                row(leftText: taskNameString(for: status, identifier: identifier), right: Text(statusString(for: status)), showChevron: true)
                    .onTapGesture { selectedTask = status }
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

    func taskDetails(for task: TasksManager.TaskStatus) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(task.shortName).font(.headline)
                Spacer()
            }
            .padding(.bottom, 14)
            row(leftText: "State", right: Text(task.state.rawValue))
            if let runningApp = task.runningInApp {
                row(leftText: "Running in", right: Text(runningApp))
            }
            if task.state == .running, let started = task.lastStarted {
                row(leftText: "Running for", right: Text("\(duration: started.age)"))
            }
            row(leftText: "Last updated", right: Text("\(task.lastUpdated, style: .relative) ago"))
            if let lastStarted = task.lastStarted {
                row(leftText: "Last started", right: Text("\(lastStarted, style: .relative) ago"))
            }
            if let lastExpired = task.lastExpired {
                row(leftText: "Last expired", right: Text("\(lastExpired, style: .relative) ago"))
            }
            if let lastCompleted = task.lastCompleted {
                row(leftText: "Last completed", right: Text("\(lastCompleted, style: .relative) ago"))
            }
            if task.state == .scheduled, task.overdueBy > 0 {
                row(leftText: "Overdue by", right: Text("\(duration: task.overdueBy)"))
            }
        }
        .padding(20)
        .alignTop()
    }

    // MARK: -

    func row(leftText: String, right rightText: Text? = nil, rightButtonText: Text? = nil, showChevron: Bool = false) -> some View {
        return HStack {
            Text(leftText)
                .font(.system(size: 12, weight: .regular))
            Spacer()
            if let rightText {
                rightText
                    .font(.system(size: 12, weight: .regular))
                    .monospacedDigit()
                    .opacity(0.6)
            }
            if let rightButtonText = rightButtonText {
                rightButtonText.font(.system(size: 12, weight: .regular))
                    .padding([.leading, .trailing], 8)
                    .foregroundColor(.white)
                    .background(Color.black)
                    .cornerRadius(10)
            }
            if showChevron {
                if #available(iOS 16.0, *) {
                    Image(systemName: "chevron.right")
                        .fontWeight(.semibold)
                        .imageScale(.small)
                        .foregroundColor(Color(uiColor: .systemGray3))
                }
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
