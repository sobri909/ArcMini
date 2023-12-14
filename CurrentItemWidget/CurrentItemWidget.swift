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
        switch family {
        case .systemSmall:
            bodySmall
                .widgetBackground(Color.clear)
        case .accessoryRectangular:
            bodyAccessoryRectangular
                .widgetBackground(Color.clear)
        default:
            fatalError()
        }
    }

    var bodySmall: some View {
        ZStack(alignment: .top) {
            if let currentItem = currentItem, let dateRange = currentItem.dateRange {
                HStack(alignment: .top) {
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
                    Spacer()
                    itemIcon.frame(width: 24, height: 24)
                }

            } else {
                Text("No Current Item!")
                    .font(.system(size: 14, weight: .semibold))
            }

            if appGroup.currentRecorder == nil {
                HStack {
                    Spacer()
                    Image("warningIcon20").renderingMode(.template).foregroundColor(.red)
                }
            }

            VStack {
                Spacer()
                HStack {
                    Text("\(Date(), style: .relative) ago")
                        .font(.system(size: 9, weight: .regular))
                        .opacity(0.3)
                    Spacer()
                    HStack(spacing: 3) {
                        ForEach(appGroup.apps.values.sorted { $0.appName.sortIndex < $1.appName.sortIndex }, id: \.updated) { appState in
                            if appState.updated.age < .oneMonth {
                                if appState.isAlive {
                                    if appState.isAliveAndRecording {
                                        Text("●")
                                            .font(.system(size: 11, weight: .regular))
                                            .foregroundColor(Color.green)
                                            .opacity(0.4)
                                    } else {
                                        Text("■")
                                            .font(.system(size: 11, weight: .regular))
                                            .foregroundColor(Color.green)
                                            .opacity(0.4)
                                    }
                                } else {
                                    Text("◆")
                                        .font(.system(size: 11, weight: .regular))
                                        .foregroundColor(Color.red)
                                        .opacity(0.4)
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding([.top, .leading, .trailing], 16)
        .padding([.bottom], 12)
    }

    var bodyAccessoryRectangular: some View {
        ZStack(alignment: .top) {
            if let currentItem = currentItem, let dateRange = currentItem.dateRange {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        if let currentItemTitle = currentItemTitle {
                            HStack(spacing: 2) {
                                itemIcon
                                    .frame(width: 16, height: 16)
                                Text(currentItemTitle)
                                    .lineLimit(1)
                                    .font(.system(size: 14, weight: .regular))
                            }
                        }
                        Text(CurrentItemWidgetEntryView.dateFormatter.string(from: dateRange.start))
                            .font(.system(size: 14, weight: .semibold))
                        Text(dateRange.start, style: .relative)
                            .font(.system(size: 14, weight: .regular))
                            .opacity(0.8)
                    }
                }

            } else {
                HStack(spacing: 2) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .frame(width: 16, height: 16)
                    Text("No current item!")
                        .font(.system(size: 14, weight: .semibold))
                }
            }
        }
        .padding(2)
    }

    var itemIcon: some View {
        if let path = currentItem as? LocoKit.Path, let activityType = path.modeActivityType {
            return AnyView(
                Image.icon(for: activityType, size: 24)
                    .resizable()
                    .renderingMode(.template)
                    .foregroundColor(Color(uiColor: UIColor.color(for: activityType)))
            )
        }
        return AnyView(EmptyView())
    }

}

@main
struct CurrentItemWidget: Widget {
    let kind: String = "CurrentItemWidget"

    // TODO: should remove the contentMarginsDisabled() eventually
    // it's a workaround for the automatic margins iOS 17 adds
    var body: some WidgetConfiguration {
        StaticConfiguration<CurrentItemWidgetEntryView>(kind: kind, provider: Provider()) { entry in
            CurrentItemWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Arc Current Item")
        .description("The current timeline item.")
        .supportedFamilies([.systemSmall, .accessoryRectangular])
        .contentMarginsDisabled()
    }
}

// workaround for iOS 17's required new background thing while still supporting iOS 16
extension View {
    func widgetBackground(_ backgroundView: some View) -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            return containerBackground(for: .widget) { backgroundView }
        } else {
            return background(backgroundView)
        }
    }
}
