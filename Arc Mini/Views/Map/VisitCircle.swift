// Created by Matt Greenfield on 9/11/15.
// Copyright (c) 2015 Big Paua. All rights reserved.

import MapKit

class VisitCircle: MKCircle, ArcAnnotation {

    var color: UIColor?

    var timelineItem: ArcTimelineItem? {
        didSet(newValue) {
            guard let item = newValue else { return }
            self.title = item.title
            if let dateRange = item.dateRange, let startString = item.startTimeString, let endString = item.endTimeString {
                subtitle = String(format: "%@ · %@ - %@", dateRange.shortDurationString, startString, endString)
            }
        }
    }

    var renderer: MKCircleRenderer {
        let renderer = MKCircleRenderer(circle: self)
        renderer.fillColor = color?.withAlphaComponent(0.4)
        renderer.strokeColor = nil
        renderer.lineWidth = 0
        return renderer
    }
    
}
