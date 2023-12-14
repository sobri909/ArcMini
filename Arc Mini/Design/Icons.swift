//
//  Icons.swift
//  Arc
//
//  Created by Matt Greenfield on 4/2/19.
//  Copyright © 2019 Big Paua. All rights reserved.
//

import UIKit
import LocoKit
import SwiftUI

extension Image {
    static func icon(for activityType: ActivityTypeName, size: Int) -> Image {
        let filename = activityType.iconFilename + String(size)
        return Image(filename).renderingMode(.template)
    }
}

extension UIImage {
    static func icon(for activityType: ActivityTypeName, size: Int) -> UIImage {
        let filename = activityType.iconFilename + String(size)
        return UIImage(named: filename)!.withRenderingMode(.alwaysTemplate)
    }
}

extension UIImageView {
    static func icon(for activityType: ActivityTypeName, size: Int, tintColor: UIColor? = nil) -> UIImageView {
        let image = UIImage.icon(for: activityType, size: size)
        let view = UIImageView(image: image)
        view.tintColor = tintColor ?? UIColor.color(for: activityType)
        return view
    }
}

extension ActivityTypeName {
    var iconFilename: String {
        switch self {
        case .walking:
            return "walkingIcon"
        case .running:
            return "runningIcon"
        case .cycling:
            return "cyclingIcon"
        case .car, .unknown:
            return "carIcon"
        case .taxi:
            return "taxiIcon"
        case .motorcycle:
            return "motorcycleIcon"
        case .train, .metro:
            return "trainIcon"
        case .tram, .cableCar, .funicular, .chairlift, .skiLift:
            return "tramIcon"
        case .airplane:
            return "airplaneIcon"
        case .bus:
            return "busIcon"
        case .boat:
            return "boatIcon"
        case .stationary, .bogus:
            return "defaultPlaceIcon"
        case .tractor:
            return "tractorIcon"
        case .tuktuk, .songthaew:
            return "tuktukIcon"
        case .skateboarding:
            return "skateboardingIcon"
        case .inlineSkating:
            return "inlineSkatingIcon"
        case .snowboarding:
            return "snowboardingIcon"
        case .skiing:
            return "skiingIcon"
        case .horseback:
            return "horsebackIcon"
        case .scooter:
            return "scooterIcon"
        case .swimming:
            return "swimmingIcon"
        case .golf:
            return "golfIcon"
        case .wheelchair:
            return "wheelchairIcon"
        case .rowing, .kayaking:
            return "rowingIcon"
        case .surfing:
            return "surfingIcon"
        case .hiking:
            return "hikingIcon"
        }
    }
}
