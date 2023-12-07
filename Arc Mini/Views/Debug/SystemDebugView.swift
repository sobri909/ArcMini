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
                    if Backups.samplesBackupQueue.operationCount > 0 {
                        self.row(leftText: "Backup samples queue jobs", right: Text("\(Backups.samplesBackupQueue.operationCount)"))
                    }
                    NavigationLink(destination: PlacesPendingUpdateView()) {
                        self.row(leftText: "Places pending update", right: Text("\(RecordingManager.store.placesPendingUpdate)"))
                    }
                    .listRowInsets(EdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 10))
                    NavigationLink(destination: ModelsPendingUpdateView()) {
                        self.row(leftText: "ActivityType models pending update", right: Text("\(RecordingManager.store.coreMLModelsPendingUpdate)"))
                    }
                    .listRowInsets(EdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 10))
                }
                backupRows
                if !runningTasks.isEmpty {
                    runningTaskRows
                }
                if !overdueTasks.isEmpty {
                    overdueTaskRows
                }
                if !waitingTasks.isEmpty {
                    waitingTaskRows
                }
                otherTaskRows
            }
            .navigationBarTitle("Arc \(Bundle.versionNumber) (\(String(format: "%d", Bundle.buildNumber)))")
            .environment(\.defaultMinListRowHeight, 28)
            .sheet(item: $selectedTask) { item in
                if #available(iOS 16.0, *) {
                    taskDetailsSheet(for: item)
                        .presentationDetents([.height(280)])
                } else {
                    taskDetailsSheet(for: item)
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

    var runningTaskRows: some View {
        Section(header: Text("Running Tasks")) {
            ForEach(runningTasks, id: \.shortName) { status in
                row(
                    leftText: taskNameString(for: status),
                    right: Text(statusString(for: status)),
                    showChevron: true
                )
                .onTapGesture { selectedTask = status }
            }
        }
    }

    var overdueTaskRows: some View {
        Section(header: Text("Overdue Tasks")) {
            ForEach(overdueTasks, id: \.shortName) { status in
                row(
                    leftText: taskNameString(for: status),
                    right: Text(statusString(for: status)),
                    showChevron: true
                )
                .onTapGesture { selectedTask = status }
            }
        }
    }

    var waitingTaskRows: some View {
        Section(header: Text("Scheduled Tasks")) {
            ForEach(waitingTasks, id: \.shortName) { status in
                row(
                    leftText: taskNameString(for: status),
                    right: Text(statusString(for: status)),
                    showChevron: true
                )
                .onTapGesture { selectedTask = status }
            }
        }
    }

    var otherTaskRows: some View {
        Section(header: Text("Other tasks")) {
            ForEach(otherTasks, id: \.shortName) { status in
                row(
                    leftText: taskNameString(for: status),
                    right: Text(statusString(for: status)),
                    showChevron: true
                )
                .onTapGesture { selectedTask = status }
            }
        }
    }

    var runningTasks: [TasksManager.TaskStatus] {
        return TasksManager.highlander.taskStates.values
            .filter { $0.state == .running }
    }

    var overdueTasks: [TasksManager.TaskStatus] {
        return TasksManager.highlander.taskStates.values
            .filter { $0.state == .scheduled && $0.minimumDelay > 0 && $0.overdueBy > 0 }
            .sorted { $0.overdueBy > $1.overdueBy }
    }

    var waitingTasks: [TasksManager.TaskStatus] {
        return TasksManager.highlander.taskStates.values
            .filter { $0.state == .scheduled && ($0.minimumDelay == 0 || $0.overdueBy <= 0) }
            .sorted { $0.lastCompleted ?? $0.lastUpdated - .oneYear > $1.lastCompleted ?? $1.lastUpdated - .oneYear }
    }

    var otherTasks: [TasksManager.TaskStatus] {
        return TasksManager.highlander.taskStates.values
            .filter { $0.state != .running && $0.state != .scheduled }
            .filter { !TasksManager.TaskIdentifier.deprecatedIdentifiers.contains($0.shortName) }
            .sorted { $0.state.sortIndex < $1.state.sortIndex }
    }

    func taskDetailsSheet(for task: TasksManager.TaskStatus) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(task.shortName).font(.headline)
                Spacer()
            }
            .padding(.bottom, 14)
            row(leftText: "State", right: Text(task.state.rawValue))
            if task.state == .running, let started = task.lastStarted {
                if let runningApp = task.lastRanInApp {
                    row(leftText: "Running in", right: Text(runningApp))
                }
                row(leftText: "Running for", right: Text("\(duration: started.age)"))
            } else if let lastApp = task.lastRanInApp {
                row(leftText: "Last ran in", right: Text(lastApp))
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

    func taskNameString(for task: TasksManager.TaskStatus) -> String {
        if task.state == .expired {
            return "✕ " + task.shortName
        }
        if task.state == .unfinished {
            return "!! " + task.shortName
        }
        if task.state == .running {
            return "▶︎ " + task.shortName
        }
        if let lastCompleted = task.lastCompleted, (task.minimumDelay == 0 || lastCompleted.age < task.minimumDelay) {
            if task.state == .scheduled {
                return "✓ ▷ " + task.shortName
            }
            return "✓ " + task.shortName
        }
        if task.state == .scheduled {
            return "▷ " + task.shortName
        }
        return String(task.shortName)
    }

    func statusString(for task: TasksManager.TaskStatus) -> String {
        if task.state == .running {
            if let lastStarted = task.lastStarted {
                return "running for \(String(duration: lastStarted.age, style: .short, maximumUnits: 1))"
            } else {
                return "running"
            }
        }
        if task.state == .scheduled, task.overdueBy > 0 {
            return "overdue by \(String(duration: task.overdueBy, style: .short, maximumUnits: 1))"
        }
        if let lastCompleted = task.lastCompleted {
            return "completed \(String(duration: -lastCompleted.timeIntervalSinceNow, style: .short, maximumUnits: 1)) ago"
        }
        if task.state == .registered { return "registered" }
        return "\(task.state.rawValue) \(String(duration: -task.lastUpdated.timeIntervalSinceNow, style: .short, maximumUnits: 1)) ago"
    }

}
