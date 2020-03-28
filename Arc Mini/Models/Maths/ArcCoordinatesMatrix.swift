//
//  ArcCoordinatesMatrix.swift
//  LearnerCoacher
//
//  Created by Matt Greenfield on 7/05/17.
//  Copyright © 2017 Big Paua. All rights reserved.
//

import Upsurge
import LocoKit
import CoreLocation

class ArcCoordinatesMatrix: CoordinatesMatrix {
    
    // only used by Places so far. only they care about maximumBinCount
    convenience init?(samples: [LocomotionSample], maximumBinCount: Int = 20) {
        let coordinates = samples.compactMap { $0.hasUsableCoordinate ? $0.location?.coordinate : nil }
        
        var lat: [Double] = []
        var lng: [Double] = []
        for coordinate in coordinates {
           lat.append((coordinate.latitude))
           lng.append((coordinate.longitude))
        }
        
        let lngMean = mean(lng)
        let latMean = mean(lat)
        let lngSD = std(lng)
        let latSD = std(lat)
        
        // trim outliers
        let xTrimRange = (min: lngMean - (lngSD * 3), max: lngMean + (lngSD * 3))
        lng = lng.filter { $0 >= xTrimRange.min && $0 <= xTrimRange.max }
        let yTrimRange = (min: latMean - (latSD * 3), max: latMean + (latSD * 3))
        lat = lat.filter { $0 >= yTrimRange.min && $0 <= yTrimRange.max }
      
        // make sure we've actually got values to work with
        guard let minLng = lng.min(), let maxLng = lng.max(), let minLat = lat.min(), let maxLat = lat.max() else {
            return nil
        }
        
        let lngRange = (min: minLng, max: maxLng)
        let latRange = (min: minLat, max: maxLat)
        
        // make sure we've got non zero ranges
        guard lngRange.min < lngRange.max, latRange.min < latRange.max else {
            return nil
        }
        
        let lngBinCount = Histogram.numberOfBins(lng).clamped(min: 0, max: maximumBinCount)
        let latBinCount = Histogram.numberOfBins(lat).clamped(min: 0, max: maximumBinCount)
       
        self.init(coordinates: coordinates, latBinCount: latBinCount, lngBinCount: lngBinCount, latRange: latRange,
                  lngRange: lngRange, pseudoCount: 1)
    }

}
