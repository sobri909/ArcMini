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
    var entry: Provider.Entry

    var body: some View {
        Text(entry.date, style: .time)
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
