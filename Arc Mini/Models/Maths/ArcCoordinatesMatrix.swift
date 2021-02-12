//
//  ArcCoordinatesMatrix.swift
//  LearnerCoacher
//
//  Created by Matt Greenfield on 7/05/17.
//  Copyright © 2017 Big Paua. All rights reserved.
//

import os.log
import CoreLocation
import Upsurge
import LocoKit
import FlatBuffers

class ArcCoordinatesMatrix: CoordinatesMatrix {
    
    convenience init?(data: Data) {
        let bb = ByteBuffer(data: data)
        let fbBins = CoordinateBins.getRootAsCoordinateBins(bb: bb)

        let latRange = (min: fbBins.latMin, max: fbBins.latMax)
        let lngRange = (min: fbBins.lonMin, max: fbBins.lonMax)
        let lngBinWidth = (lngRange.max - lngRange.min) / Double(fbBins.lonBinsCount)
        let latBinWidth = (latRange.max - latRange.min) / Double(fbBins.latBinsCount)
        
        var bins = Array(repeating: Array<UInt16>(repeating: fbBins.pseudoCount, count: Int(fbBins.lonBinsCount)), count: Int(fbBins.latBinsCount))
        
        for i in 0..<fbBins.latBinsCount {
            guard let fbRow = fbBins.latBins(at: i) else { print("shit"); continue }
            let lonBins = fbRow.lonBins
            bins[Int(i)] = lonBins
        }
        
        self.init(bins: bins, latBinWidth: latBinWidth, lngBinWidth: lngBinWidth, latRange: latRange,
                  lngRange: lngRange, pseudoCount: fbBins.pseudoCount)
    }

    
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
    
    var serialisedData: Data {
        var builder = FlatBufferBuilder(initialSize: 1)
        var fbRows: [Offset<UOffset>] = []
        for row in bins {
            let vector = builder.createVector(row)
            let fbRow = BinsRow.createBinsRow(&builder, vectorOfLonBins: vector)
            fbRows.append(fbRow)
        }
        let rowsVector = builder.createVector(ofOffsets: fbRows)
        let fbBins = CoordinateBins.createCoordinateBins(&builder, pseudoCount: pseudoCount,
                                                         latMin: latRange.min, latMax: latRange.max,
                                                         lonBinsCount: UInt16(bins[0].count), lonMin: lngRange.min, lonMax: lngRange.max,
                                                         vectorOfLatBins: rowsVector)
        builder.finish(offset: fbBins)
        return builder.data
    }

}
