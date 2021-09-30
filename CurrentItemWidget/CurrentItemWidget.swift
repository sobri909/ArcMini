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
        guard let app = appGroup.currentRecorder ?? appGroup.sortedApps.first else { return nil }
        guard let itemId = app.currentItemId else { return nil }
        return store.item(for: itemId)
    }

    var body: some View {
        ZStack(alignment: .top) {
            if let currentItem = currentItem, let dateRange = currentItem.dateRange {
                VStack(alignment: .leading) {
                    if let currentItemTitle = currentItemTitle {
                        Text(currentItemTitle)
                            .font(.system(size: 14, weight: .semibold))
                    }
                    Text(CurrentItemWidgetEntryView.dateFormatter.string(from: dateRange.start))
                        .font(.system(size: 26, weight: .regular))
                    Text(dateRange.start, style: .relative)
                        .font(.system(size: 10, weight: .regular))
                        .opacity(0.6)
                    Spacer()
                }

            } else {
                Text("No Current Item!")
                    .font(.system(size: 14, weight: .semibold))
            }

            if appGroup.currentRecorder == nil {
                HStack {
                    Spacer()
                    Image("warningIcon20").renderingMode(.template).foregroundColor(Color.red)
                }
            }
            
            VStack {
                Spacer()
                HStack {
                    Text(Date(), style: .relative)
                        .font(.system(size: 8, weight: .regular))
                        .opacity(0.3)
                    Spacer()
                    HStack(spacing: 3) {
                        ForEach(appGroup.apps.values.sorted { $0.appName.sortIndex < $1.appName.sortIndex }, id: \.updated) { appState in
                            if appState.isAlive {
                                Text("●")
                                    .font(.system(size: 8, weight: .regular))
                                    .foregroundColor(Color.green)
                                    .opacity(0.4)
                            } else {
                                Text("■")
                                    .font(.system(size: 10, weight: .regular))
                                    .foregroundColor(Color.red)
                                    .opacity(0.4)
                            }
                        }
                    }
                }
            }
        }
        .padding([.top, .leading, .trailing], 16)
        .padding([.bottom], 12)
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
        .supportedFamilies([.systemSmall])
    }
}
