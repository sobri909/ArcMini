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
            Text(entry.date, style: .time)
            ForEach(appGroup.sortedApps, id: \.updated) { appState in
                self.row(
                    leftText: appState.appName.rawValue,
                    rightText: "\(appState.recordingState.rawValue) (\(String(duration: appState.updated.age)) ago)",
                    highlight: appState.isAliveAndRecording, fade: !appState.isAlive
                ).frame(height: 20)
            }
        }.padding([.leading, .trailing], 20)
    }

    func row(leftText: String, rightText: String, highlight: Bool = false, fade: Bool = false) -> some View {
        let font = highlight ? Font.system(.footnote).bold() : Font.system(.footnote)
        return HStack {
            Text(leftText).font(font).opacity(fade ? 0.6 : 1)
            Spacer()
            Text(rightText).font(font).opacity(0.6).opacity(fade ? 0.6 : 1)
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
