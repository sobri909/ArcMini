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

    func placeholder(in context: Context) -> SimpleEntry {
        return SimpleEntry(date: Date())
    }

    public func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date())
        completion(entry)
    }

    public func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let entries: [SimpleEntry] = [SimpleEntry(date: Date())]
        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    public let date: Date
}

struct RecordersWidgetEntryView: View {

    @Environment(\.widgetFamily) var family
    var entry: Provider.Entry

    let appGroup = AppGroup(appName: .arcMini, suiteName: "group.ArcApp", readOnly: true)

    var body: some View {
        VStack(alignment: .leading) {
            if family == .systemSmall {
                HStack {
                    (Text(entry.date, style: .relative) + Text(" ago")).font(.system(.headline))
                    Spacer()
                }.frame(height: 40)
            } else {
                HStack {
                    Text("ARC RECORDERS").font(.system(.headline))
                    Spacer()
                    (Text(entry.date, style: .relative) + Text(" ago")).font(.system(.headline))
                }.frame(height: 40)
            }
            ForEach(appGroup.sortedApps, id: \.updated) { appState in
                if appState.isAlive || family == .systemSmall {
                    self.row(
                        leftText: appState.appName.rawValue,
                        rightText: Text(appState.recordingState.rawValue),
                        isActiveRecorder: appState.isAliveAndRecording, isAlive: appState.isAlive
                    ).frame(height: 28)
                } else {
                    self.row(
                        leftText: appState.appName.rawValue,
                        rightText: Text(appState.recordingState.rawValue) + Text(" (") + Text(appState.updated, style: .relative) + Text(" ago)"),
                        isActiveRecorder: appState.isAliveAndRecording, isAlive: false
                    ).frame(height: 28)
                }
            }
        }.padding([.leading, .trailing], family == .systemSmall ? 12 : 20)
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
        StaticConfiguration<RecordersWidgetEntryView>(kind: kind, provider: Provider()) { entry in
            RecordersWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Arc Recorders")
        .description("Status of Arc recorders.")
    }
}
