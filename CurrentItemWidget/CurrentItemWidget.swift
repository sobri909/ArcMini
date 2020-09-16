//
//  CurrentItemWidget.swift
//  CurrentItemWidget
//
//  Created by Matt Greenfield on 11/9/20.
//  Copyright © 2020 Matt Greenfield. All rights reserved.
//

import WidgetKit
import SwiftUI
import LocoKit

struct Provider: TimelineProvider {
    typealias Entry = SimpleEntry

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
    let date: Date
}

struct CurrentItemWidgetEntryView : View {

    @Environment(\.widgetFamily) var family
    var entry: Provider.Entry

    let store = MiniStore()
    let appGroup = AppGroup(appName: .arcMini, suiteName: "group.ArcApp", readOnly: true)
    
    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    var currentItemTitle: String? {
        return appGroup.currentRecorder?.currentItemTitle
    }

    var currentItem: TimelineItem? {
        guard let itemId = appGroup.currentRecorder?.currentItemId else { return nil }
        return store.item(for: itemId)
    }

    var body: some View {
        VStack(alignment: .leading) {
//            if let currentRecorder = appGroup.currentRecorder {
//                Text(currentRecorder.updated, style: .relative) + Text(" ago")
//            }
            if let currentItem = currentItem, let dateRange = currentItem.dateRange {
                VStack(alignment: .leading) {
                    if let currentItemTitle = currentItemTitle {
                        Text(currentItemTitle)
                    }
                    Text(CurrentItemWidgetEntryView.dateFormatter.string(from: dateRange.start))
                        .font(.system(size: 16, weight: .medium))
                    Text(dateRange.start, style: .relative)
                        .font(.system(size: 13, weight: .regular))
                }

            } else {
                Text("No currentItem!")
            }
        }.padding([.leading, .trailing], family == .systemSmall ? 12 : 20)
    }
    
}

@main
struct CurrentItemWidget: Widget {
    let kind: String = "CurrentItemWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration<CurrentItemWidgetEntryView>(kind: kind, provider: Provider()) { entry in
            CurrentItemWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Arc Current Item")
        .description("The current Arc timeline item.")
    }
}
