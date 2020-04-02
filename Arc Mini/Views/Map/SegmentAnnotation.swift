//
//  SegmentAnnotation.swift
//  Arc Mini
//
//  Created by Matt Greenfield on 2/4/20.
//  Copyright © 2020 Matt Greenfield. All rights reserved.
//

import MapKit

class SegmentAnnotation: NSObject, MKAnnotation {

    var coordinate: CLLocationCoordinate2D

    init(coordinate: CLLocationCoordinate2D) {
        self.coordinate = coordinate
        super.init()
    }

    var view: SegmentAnnotationView {
        return SegmentAnnotationView(annotation: self, reuseIdentifier: nil)
    }

}
