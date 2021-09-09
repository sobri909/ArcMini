//
//  TimelineState.swift
//  Arc Mini
//
//  Created by Matt Greenfield on 31/3/20.
//  Copyright © 2020 Matt Greenfield. All rights reserved.
//

import LocoKit
import Combine

class TimelineState: ObservableObject {
    
    static let highlander = TimelineState()

    static let rootMapHeightPercent: CGFloat = 0.4
    static let subMapHeightPercent: CGFloat = 0.4 // should be 0.35, but view sizing is an issue at the moment

    static let dateFormatter = DateFormatter() // reusable cached formatter

    @Published var dateRanges: Array<DateInterval> = []
    @Published var currentCardIndex = 0

    @Published var mapHeightPercent: CGFloat = rootMapHeightPercent
    var bodyHeightPercent: CGFloat { return 1.0 - mapHeightPercent }
    
    @Published var backButtonHidden = true
    @Published var todayButtonHidden = true

    @Published var tappedBackButton = false
    @Published var tappedTodayButton = false

    private var cardIndexObserver: AnyCancellable?

    init() {
        dateRanges.append(Calendar.current.dateInterval(of: .day, for: Date().previousDay)!)
        dateRanges.append(Calendar.current.dateInterval(of: .day, for: Date())!)
        currentCardIndex = 1

        cardIndexObserver = $currentCardIndex
            .removeDuplicates()
            .debounce(for: 0.3, scheduler: DispatchQueue.main)
            .sink { newCardIndex in
                self.updateTodayButton(newCardIndex: newCardIndex)
                self.updateEdges()
        }

    }

    var visibleDateRange: DateInterval? {
        guard currentCardIndex < dateRanges.count else { return nil }
        return dateRanges[currentCardIndex]
    }

    var visibleTimelineSegment: TimelineSegment? {
        guard let dateRange = visibleDateRange else { return nil }
        return RecordingManager.store.segment(for: dateRange)
    }

    // MARK: -

    func gotoPrevious() {
        guard let visibleDateRange = visibleDateRange else { return }
        goto(date: visibleDateRange.middle.previousDay)
    }

    func gotoNext() {
        guard let visibleDateRange = visibleDateRange else { return }
        goto(date: visibleDateRange.middle.nextDay)
    }

    func goto(date: Date) {
        guard date.endOfDay > Settings.firstDate else { return }
        guard date.startOfDay.timeIntervalSinceNow < 0 else { return }

        guard let range = Calendar.current.dateInterval(of: .day, for: date) else { return }

        if !dateRanges.contains(range) {
            dateRanges.append(range)
            dateRanges.sort { $0 < $1 }
        }

        guard let index = dateRanges.firstIndex(of: range) else { return }

        currentCardIndex = index
    }

    // MARK: -

    func updateTodayButton(newCardIndex: Int? = nil) {
        let dateRange = dateRanges[newCardIndex ?? currentCardIndex]
        todayButtonHidden = dateRange.containsNow
    }

    func updateEdges() {
        if currentCardIndex == 0, let firstRange = dateRanges.first {
            dateRanges.insert(firstRange.previousRange(of: .day)!, at: 0)
            currentCardIndex += 1
        }
        if currentCardIndex == dateRanges.count - 1, let lastRange = dateRanges.last {
            if let nextRange = lastRange.nextRange(of: .day), (nextRange.start.timeIntervalSinceNow < 0 || nextRange.containsNow) {
                dateRanges.append(nextRange)
            }
        }
    }

}
