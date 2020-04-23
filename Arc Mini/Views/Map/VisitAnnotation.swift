// Created by Matt Greenfield on 21/01/16.
// Copyright (c) 2016 Big Paua. All rights reserved.

import MapKit

class VisitAnnotation: NSObject, ArcAnnotation {

    var coordinate: CLLocationCoordinate2D
    var title: String?
    var subtitle: String?
    var visit: ArcVisit
    var timelineItem: ArcTimelineItem? { return visit }

    init(coordinate: CLLocationCoordinate2D, visit: ArcVisit) {
        self.coordinate = coordinate
        self.title = visit.title
        if let dateRange = visit.dateRange, let startString = visit.startTimeString, let endString = visit.endTimeString {
            subtitle = String(format: "%@ · %@ - %@", dateRange.shortDurationString, startString, endString)
        }
        self.visit = visit
        super.init()
    }

    var view: VisitAnnotationView {
        let view = VisitAnnotationView(annotation: self, reuseIdentifier: nil)
        if title != nil {
            view.canShowCallout = true
            view.rightCalloutAccessoryView = UIImageView(image: UIImage(systemName: "chevron.right"))
        }
        return view
    }
    
}
