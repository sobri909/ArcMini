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

    @ObservedObject var mapState: MapState
    @ObservedObject var timelineState: TimelineState

    init(mapState: MapState, timelineState: TimelineState) {
        self.mapState = mapState
        self.timelineState = timelineState
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

        if let segment = timelineState.visibleTimelineSegment {
            for timelineItem in segment.timelineItems {
                let disabled = isDisabled(timelineItem)

                if let path = timelineItem as? ArcPath {
                    if let overlay = add(path, to: map, disabled: disabled), !disabled {
                        if mapState.itemSegments.isEmpty { zoomOverlays.append(overlay) }
                    }

                } else if let visit = timelineItem as? ArcVisit {
                    if let overlay = add(visit, to: map, disabled: disabled), !disabled {
                        if mapState.itemSegments.isEmpty { zoomOverlays.append(overlay) }
                    }
                }
            }
        }

        for segment in mapState.itemSegments {
            if let overlay = add(segment, to: map) {
                zoomOverlays.append(overlay)
            }
        }

        zoomToShow(overlays: zoomOverlays, in: map)
    }

    func isDisabled(_ timelineItem: TimelineItem) -> Bool {
        if !mapState.itemSegments.isEmpty { return true }
        if mapState.selectedItems.isEmpty { return false }
        return !mapState.selectedItems.contains(timelineItem)
    }

    // MARK: - Adding map elements

    func add(_ path: ArcPath, to map: MKMapView, disabled: Bool) -> MKOverlay? {
        if path.samples.isEmpty { return nil }

        var coords = path.samples.compactMap { $0.location?.coordinate }
        let line = PathPolyline(coordinates: &coords, count: coords.count, color: path.uiColor, disabled: disabled)
        map.addOverlay(line)

        return line
    }

    func add(_ visit: ArcVisit, to map: MKMapView, disabled: Bool) -> MKOverlay? {
        guard let center = visit.center else { return nil }

        if !disabled {
            map.addAnnotation(VisitAnnotation(coordinate: center.coordinate, visit: visit))
        }

        let circle = VisitCircle(center: center.coordinate, radius: visit.radius2sd)
        circle.timelineItem = visit
        circle.color = disabled ? .lightGray : .arcSelected
        map.addOverlay(circle, level: .aboveLabels)

        return circle
    }

    func add(_ segment: ItemSegment, to map: MKMapView) -> MKOverlay? {
        if segment.samples.isEmpty { return nil }

        // a stationary segment? add annotation and circle
        if segment.activityType == .stationary, let center = segment.center {
            map.addAnnotation(SegmentAnnotation(coordinate: center.coordinate))

            let circle = VisitCircle(center: center.coordinate, radius: segment.radius.with1sd)
            circle.color = .arcSelected
            map.addOverlay(circle, level: .aboveLabels)

            return circle
        }

        // only one sample? add it alone, with annotation
        if segment.samples.count == 1, let sample = segment.samples.first {
            return add(sample, to: map)
        }
        
        var coords = segment.samples.compactMap { $0.location?.coordinate }

        if !coords.isEmpty {
            let line = PathPolyline(coordinates: &coords, count: coords.count, color: segment.activityType?.color ?? .black)
            map.addOverlay(line)
            return line
        }

        return nil
    }

    func add(_ sample: LocomotionSample, to map: MKMapView) -> MKOverlay? {
        guard sample.hasUsableCoordinate else { return nil }
        guard let location = sample.location else { return nil }

        map.addAnnotation(SegmentAnnotation(coordinate: location.coordinate))

        if sample.activityType == .stationary {
            let circle = VisitCircle(center: location.coordinate, radius: location.horizontalAccuracy)
            circle.color = .arcSelected
            map.addOverlay(circle, level: .aboveLabels)
            return circle
        }

        return nil
    }

    // MARK: - Zoom

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

        // NOTE: iPhone X notch is 30px high, and top safe area is 44px. so to get 20px padding from notch the top padding is 6px
        let safeHeight = UIScreen.main.bounds.height - map.safeAreaInsets.top - map.safeAreaInsets.bottom
        let padding = UIEdgeInsets(top: 6, left: 20, bottom: safeHeight * timelineState.bodyHeightPercent + 20, right: 20)

        map.setVisibleMapRect(mapRect!, edgePadding: padding, animated: true)
    }

    // MARK: - MKMapViewDelegate

    func makeCoordinator() -> Coordinator {
        Coordinator(self, mapState: mapState)
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapView
        var mapState: MapState

        init(_ parent: MapView, mapState: MapState) {
            self.parent = parent
            self.mapState = mapState
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let path = overlay as? PathPolyline { return path.renderer }
            if let circle = overlay as? VisitCircle { return circle.renderer }
            fatalError("you wot?")
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if let annotation = annotation as? VisitAnnotation { return annotation.view }
            if let annotation = annotation as? SegmentAnnotation { return annotation.view }
            return nil
        }

        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            mapState.selectedTimelineItem = (view.annotation as? ArcAnnotation)?.timelineItem
            guard let callout = view.subviews.first else { return }
            let tapper = UITapGestureRecognizer(target: self, action: #selector(tappedCallout))
            callout.addGestureRecognizer(tapper)
        }

        @objc func tappedCallout() {
            mapState.tappedSelectedItem = true
        }
    }

}

//struct MapView_Previews: PreviewProvider {
//    static var previews: some View {
//        MapView()
//    }
//}
