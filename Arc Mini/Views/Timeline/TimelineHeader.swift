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
    @State var showingDebugLogs = false
    @State var showingMenu = false

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
        .actionSheet(isPresented: $showingMenu) {
            ActionSheet(title: Text("Timeline").foregroundColor(Color.red), buttons: [
                .default(Text("Debug Log")) {
                    self.showingDebugLogs = true
                },
                .destructive(Text("Close"))
            ])
        }
        .sheet(isPresented: $showingDebugLogs) {
            DebugLogsView().environmentObject(DebugLogger.highlander)
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
