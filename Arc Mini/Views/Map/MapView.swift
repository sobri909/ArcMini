//
//  MapView.swift
//  Arc Mini
//
//  Created by Matt Greenfield on 6/3/20.
//  Copyright © 2020 Matt Greenfield. All rights reserved.
//

import SwiftUI
import LocoKit
import MapKit

struct MapView: UIViewRepresentable {

    @ObservedObject var segment: TimelineSegment

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        print("MapView.updateUIView")

        map.removeOverlays(map.overlays)
        map.removeAnnotations(map.annotations)

        for timelineItem in segment.timelineItems {
            if let path = timelineItem as? ArcPath {
                add(path, to: map)

            } else if let visit = timelineItem as? ArcVisit {
                add(visit, to: map)
            }
        }

        zoomToShow(overlays: map.overlays, in: map)
    }

    func add(_ path: ArcPath, to map: MKMapView) {
        if path.samples.isEmpty { return }

        var coords = path.samples.compactMap { $0.location?.coordinate }
        let line = PathPolyline(coordinates: &coords, count: coords.count)
        line.color = path.uiColor

        map.addOverlay(line)
    }

    func add(_ visit: Visit, to map: MKMapView) {
        guard let center = visit.center else { return }

        map.addAnnotation(VisitAnnotation(coordinate: center.coordinate, visit: visit))

        let circle = VisitCircle(center: center.coordinate, radius: visit.radius2sd)
        circle.color = .arcPurple
        map.addOverlay(circle, level: .aboveLabels)
    }

    func zoomToShow(overlays: [MKOverlay], in map: MKMapView) {
        guard !overlays.isEmpty else { return }

        var mapRect: MKMapRect?
        for overlay in overlays {
            if mapRect == nil {
                mapRect = overlay.boundingMapRect
            } else {
                mapRect = mapRect!.union(overlay.boundingMapRect)
            }
        }

        let padding = UIEdgeInsets(top: 20, left: 20, bottom: 420, right: 20)

        map.setVisibleMapRect(mapRect!, edgePadding: padding, animated: true)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapView

        init(_ parent: MapView) {
            self.parent = parent
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let path = overlay as? PathPolyline { return path.renderer }
            if let circle = overlay as? VisitCircle { return circle.renderer }
            fatalError("you wot?")
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            return (annotation as? VisitAnnotation)?.view
        }
    }

}

//struct MapView_Previews: PreviewProvider {
//    static var previews: some View {
//        MapView()
//    }
//}
