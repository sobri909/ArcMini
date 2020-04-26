//
//  GPX.swift
//  LearnerCoacher
//
//  Created by Matt Greenfield on 21/05/17.
//  Copyright © 2017 Big Paua. All rights reserved.
//

import AEXML
import LocoKit

class GPX {
    
    // MARK: - Properties

    let timelineSegment: TimelineSegment?
    let timelineItem: TimelineItem?

    var timelineItems: [TimelineItem] {
        if let timelineSegment = timelineSegment { return timelineSegment.timelineItems }
        if let timelineItem = timelineItem { return [timelineItem] }
        return []
    }
    
    private let doc = AEXMLDocument()

    // MARK: - Initialisers
    
    init(path: ArcPath) {
        self.timelineItem = path
        self.timelineSegment = nil
    }
    
    init(segment: TimelineSegment) {
        self.timelineSegment = segment
        self.timelineItem = nil
    }

    // MARK: - Export

    func exportToFile(filenameType: Calendar.Component) -> URL? {
        guard let filename = timelineSegment?.filename(for: filenameType) ?? singleItemFilename else { return nil }

        let url = NSURL.fileURL(withPath: NSTemporaryDirectory() + filename + ".gpx")

        do {
            try self.xmlString.write(to: url, atomically: false, encoding: .utf8)
            return url

        } catch {
            logger.error("\(error)")
            return nil
        }
    }
   
    // MARK: - Lazy properties
    
    private lazy var isoFormatter: DateFormatter = {
        let isoFormatter = DateFormatter()
        isoFormatter.locale = Locale(identifier: "en_US_POSIX")
        isoFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
        return isoFormatter
    }()
    
    private lazy var root: AEXMLElement = {
        let attributes = [
            "version": "1.1",
            "xmlns": "http://www.topografix.com/GPX/1/1",
            "xmlns:xsi":"http://www.w3.org/2001/XMLSchema-instance",
            "creator": "Arc Mini"
        ]
        return self.doc.addChild(name: "gpx", attributes: attributes)
    }()

    private lazy var singleItemFilename: String? = {
        guard let startDate = timelineItem?.startDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HHmm"
        return formatter.string(from: startDate)
    }()

    lazy var xmlString: String = {
        
        // adding a single path?
        if self.timelineItems.count == 1, let path = self.timelineItems.first as? ArcPath {
            
            // add the start waypoint
            if let startVisit = path.previousItem as? ArcVisit {
                self.add(startVisit)
            }

            // add the path
            self.add(path)

            // add the end waypoint
            if let endVisit = path.nextItem as? ArcVisit {
                self.add(endVisit)
            }
            
        } else {
            for item in self.timelineItems {
                if let visit = item as? ArcVisit {
                    self.add(visit)
                } else if let path = item as? ArcPath {
                    self.add(path)
                }
            }
        }
        
        return self.doc.xml
    }()

    // MARK: - Builders

    private func add(_ visit: ArcVisit) {
        guard let coord = visit.center?.coordinate else { return }
        
        let attributes = ["lat": String(coord.latitude), "lon": String(coord.longitude)]
        let waypoint = root.addChild(name: "wpt", attributes: attributes)

        if let startDate = visit.startDate {
            waypoint.addChild(name: "time", value: isoFormatter.string(from: startDate))
        }

        if let altitude = visit.altitude {
            waypoint.addChild(name: "ele", value: String(altitude))
        }

        waypoint.addChild(name: "name", value: visit.title)

        if let place = visit.place {
            if let foursquareVenueId = place.foursquareVenueId, !foursquareVenueId.isEmpty {
                let attributes = ["href": "http://foursquare.com/venue/" + foursquareVenueId]
                waypoint.addChild(name: "link", attributes: attributes)
            }
            if let facebookPlaceId = place.facebookPlaceId, !facebookPlaceId.isEmpty {
                let attributes = ["href": "http://facebook.com/" + facebookPlaceId]
                waypoint.addChild(name: "link", attributes: attributes)
            }
        }
    }

    private func add(_ path: ArcPath) {
        for segment in path.segmentsByActivityType {
            let track = root.addChild(name: "trk")
            
            if let activityType = segment.activityType {
                track.addChild(name: "type", value: activityType.rawValue)
            }

            let trackSegment = track.addChild(name: "trkseg")
            for sample in segment.samples {
                guard let location = sample.location else { continue }
                let attributes = ["lat": String(location.coordinate.latitude), "lon": String(location.coordinate.longitude)]
                let point = trackSegment.addChild(name: "trkpt", attributes: attributes)
                point.addChild(name: "ele", value: String(location.altitude))
                point.addChild(name: "time", value: isoFormatter.string(from: sample.date))
            }
        }
    }

}
