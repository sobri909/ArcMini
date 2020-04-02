//
//  SegmentAnnotationView.swift
//  Arc Mini
//
//  Created by Matt Greenfield on 2/4/20.
//  Copyright © 2020 Matt Greenfield. All rights reserved.
//

import MapKit

class SegmentAnnotationView: MKAnnotationView {

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        image = UIImage(named: "segmentAnnotation")
        centerOffset = CGPoint(x: -0.5, y: 3)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

}
