//
//  TimelineHeader.swift
//  Arc Mini
//
//  Created by Matt Greenfield on 10/3/20.
//  Copyright © 2020 Matt Greenfield. All rights reserved.
//

import SwiftUI

struct TimelineHeader: View {

    @EnvironmentObject var timelineState: TimelineState

    @State var showingMenu = false
    @State var showingDebugView = false
    @State var debugView: DebugView = .logs

    enum DebugView { case logs, recording }

    var body: some View {
        HStack {
            Text(dailyTitle)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(Color("brandTertiaryDark"))
            Spacer()
            Button(action: {
                self.showingMenu = true
            }) {
                Image(systemName: "ellipsis").foregroundColor(Color("brandSecondary80"))
            }
            .frame(width: 56, height: 56)
        }
        .padding([.leading], 20)
        .padding([.trailing], 4)
        .frame(height: 56)
        .background(Color("background"))
        .sheet(isPresented: $showingDebugView) {
            if self.debugView == .logs {
                DebugLogsView().environmentObject(DebugLogger.highlander)
            } else if self.debugView == .recording {
                RecordingDebugView()
            }
        }
        .actionSheet(isPresented: $showingMenu) {
            ActionSheet(title: Text("Timeline").foregroundColor(Color.red), buttons: [
                .default(Text("Debug Logs")) {
                    self.debugView = .logs
                    self.showingDebugView = true
                },
                .default(Text("Recording Debug Info")) {
                    self.debugView = .recording
                    self.showingDebugView = true
                },
                .destructive(Text("Close"))
            ])
        }
    }

    var dailyTitle: String {
        guard let day = timelineState.visibleDateRange?.start else { return "Eh?" }
        let formatter = TimelineState.dateFormatter
        if day.isToday || day.isYesterday {
            formatter.dateFormat = nil
            formatter.doesRelativeDateFormatting = true
            formatter.dateStyle = .long
            formatter.timeStyle = .none
        } else {
            formatter.setLocalizedDateFormatFromTemplate("EEE d MMM yyyy")
        }
        return formatter.string(from: day)
    }
    
}

struct TimelineHeader_Previews: PreviewProvider {
    static var previews: some View {
        TimelineHeader()
    }
}
