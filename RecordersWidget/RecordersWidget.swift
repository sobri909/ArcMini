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
        ZStack(alignment: .top) {
            VStack(alignment: .leading) {
                HStack {
                    Text("Arc Recorders").font(.system(size: 14, weight: .semibold))
                        .frame(height: 28)
                }
                ForEach(appGroup.apps.values.sorted { $0.appName.sortIndex < $1.appName.sortIndex }, id: \.updated) { appState in
                    if appState.isAlive || family == .systemSmall {
                        self.row(
                            leftText: appState.isAlive ? Text(appState.recordingState.rawValue) : Text("dead"),
                            rightText: Text(appState.appName.rawValue),
                            isActiveRecorder: appState.isAliveAndRecording, isAlive: appState.isAlive
                        ).frame(height: 28)
                    } else {
                        self.row(
                            leftText: Text("dead (") + Text(appState.updated, style: .relative) + Text(" ago)"),
                            rightText: Text(appState.appName.rawValue),
                            isActiveRecorder: appState.isAliveAndRecording, isAlive: false
                        ).frame(height: 28)
                    }
                }
                Spacer()
            }
            
            if appGroup.currentRecorder == nil {
                HStack {
                    Spacer()
                    Image("warningIcon20").renderingMode(.template).foregroundColor(Color.red)
                }
            }
            
            VStack {
                Spacer()
                Text(Date(), style: .relative)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 8, weight: .regular))
                    .opacity(0.3)
            }
        }
        .padding([.top, .leading, .trailing], family == .systemSmall ? 16 : 20)
        .padding([.bottom], 4)
    }

    func row(leftText: Text, rightText: Text, isActiveRecorder: Bool = false, isAlive: Bool = false) -> some View {
        return HStack {
            leftText.font(isActiveRecorder ? Font.system(.footnote).bold() : Font.system(.footnote)).opacity(isAlive ? 0.6 : 0.4)
            Spacer()
            rightText.font(Font.system(.footnote).bold())
//                .opacity(isAlive ? 1 : 0.4)
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
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
