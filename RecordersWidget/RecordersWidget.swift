//
//  RecordersWidget.swift
//  RecordersWidget
//
//  Created by Matt Greenfield on 28/6/20.
//  Copyright © 2020 Matt Greenfield. All rights reserved.
//

import WidgetKit
import SwiftUI
import LocoKit

struct Provider: TimelineProvider {
    public typealias Entry = SimpleEntry

    let appGroup = AppGroup(appName: .arcMini, suiteName: "group.ArcApp", readOnly: true)

    public func snapshot(with context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date(), sortedApps: appGroup.sortedApps)
        completion(entry)
    }

    public func timeline(with context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let appGroup = AppGroup(appName: .arcMini, suiteName: "group.ArcApp", readOnly: true)
        let entries: [SimpleEntry] = [SimpleEntry(date: Date(), sortedApps: appGroup.sortedApps)]
        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    public let date: Date
    public let sortedApps: [LocoKit.AppGroup.AppState]
}

struct PlaceholderView: View {
    var body: some View {
        Text("Placeholder View")
    }
}

struct RecordersWidgetEntryView: View {
    var entry: Provider.Entry

    let appGroup = AppGroup(appName: .arcMini, suiteName: "group.ArcApp", readOnly: true)

    var body: some View {
        VStack {
            HStack {
                Text("ARC RECORDERS").font(.system(.headline))
                Spacer()
                (Text(entry.date, style: .relative) + Text(" ago")).font(.system(.headline))
            }.frame(height: 40)
            ForEach(appGroup.sortedApps, id: \.updated) { appState in
                if appState.isAlive {
                    self.row(
                        leftText: appState.appName.rawValue,
                        rightText: Text(appState.recordingState.rawValue),
                        isActiveRecorder: appState.isAliveAndRecording, isAlive: true
                    ).frame(height: 28)
                } else {
                    self.row(
                        leftText: appState.appName.rawValue,
                        rightText: Text(appState.recordingState.rawValue) + Text(" (") + Text(appState.updated, style: .relative) + Text(" ago)"),
                        isActiveRecorder: appState.isAliveAndRecording, isAlive: false
                    ).frame(height: 28)
                }
            }
        }.padding([.leading, .trailing], 20)
    }

    func row(leftText: String, rightText: Text, isActiveRecorder: Bool = false, isAlive: Bool = false) -> some View {
        let font = isActiveRecorder ? Font.system(.footnote).bold() : Font.system(.footnote)
        return HStack {
            Text(leftText).strikethrough(!isAlive).font(font).opacity(isAlive ? 1 : 0.6)
            Spacer()
            rightText.strikethrough(!isAlive).font(font).opacity(0.6)
        }
    }

}

@main
struct RecordersWidget: Widget {
    private let kind: String = "RecordersWidget"

    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider(), placeholder: PlaceholderView()) { entry in
            RecordersWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Arc Recorders")
        .description("The currently alive Arc recorders.")
    }
}
