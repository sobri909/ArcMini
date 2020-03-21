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

final class MapView: UIViewRepresentable {

    @ObservedObject var segment: TimelineSegment
    @ObservedObject var selectedItems: ObservableItems

    init(segment: TimelineSegment, selectedItems: ObservableItems) {
        self.segment = segment
        self.selectedItems = selectedItems
    }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.isPitchEnabled = false
        map.isRotateEnabled = false
        map.delegate = context.coordinator
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        map.removeOverlays(map.overlays)
        map.removeAnnotations(map.annotations)

        var zoomOverlays: [MKOverlay] = []

        for timelineItem in segment.timelineItems {
            let disabled = (!selectedItems.items.isEmpty && !selectedItems.items.contains(timelineItem))

            if let path = timelineItem as? ArcPath {
                if let overlay = add(path, to: map, disabled: disabled), !disabled {
                    zoomOverlays.append(overlay)
                }

            } else if let visit = timelineItem as? ArcVisit {
                if let overlay = add(visit, to: map, disabled: disabled), !disabled {
                    zoomOverlays.append(overlay)
                }

            }
        }

        zoomToShow(overlays: zoomOverlays, in: map)
    }

    func add(_ path: ArcPath, to map: MKMapView, disabled: Bool) -> MKOverlay? {
        if path.samples.isEmpty { return nil }

        var coords = path.samples.compactMap { $0.location?.coordinate }
        let line = PathPolyline(coordinates: &coords, count: coords.count, color: path.uiColor, disabled: disabled)

        map.addOverlay(line)

        return line
    }

    func add(_ visit: Visit, to map: MKMapView, disabled: Bool) -> MKOverlay? {
        guard let center = visit.center else { return nil }

        if !disabled {
            map.addAnnotation(VisitAnnotation(coordinate: center.coordinate, visit: visit))
        }

        let circle = VisitCircle(center: center.coordinate, radius: visit.radius2sd)
        circle.color = disabled ? .lightGray : .arcPurple
        map.addOverlay(circle, level: .aboveLabels)

        return circle
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
