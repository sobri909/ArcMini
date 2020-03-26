//
//  Colors.swift
//  Arc Mini
//
//  Created by Matt Greenfield on 10/3/20.
//  Copyright © 2020 Matt Greenfield. All rights reserved.
//

import SwiftUI
import LocoKit

extension Color {

    static var arcSelected: Color { return Color(0x9A217D) }

    // MARK: - Hex init

    // https://stackoverflow.com/a/56894458/790036
    init(_ hex: Int, alpha: Double = 1) {
        let components = (
            R: Double((hex >> 16) & 0xff) / 255,
            G: Double((hex >> 08) & 0xff) / 255,
            B: Double((hex >> 00) & 0xff) / 255
        )
        self.init(
            .sRGB,
            red: components.R,
            green: components.G,
            blue: components.B,
            opacity: alpha
        )
    }

}

extension UIColor {

    // MARK: - Branding Blacks and Grays

    static var arcBlack: UIColor { return UIColor(0x282828) }

    static var arcGray1: UIColor { return UIColor(0x6F7072) }
    static var arcGray2: UIColor { return UIColor(0x999999) }
    static var arcGray3: UIColor { return UIColor(0xE2E2E2) }

    static var arcGrey1: UIColor { return arcGray1 }
    static var arcGrey2: UIColor { return arcGray2 }
    static var arcGrey3: UIColor { return arcGray3 }

    // MARK: - Branding Colours

    static var arcDarkPurple: UIColor { return UIColor(0x2D2D73) }
    static var arcPurple: UIColor { return UIColor(0x7A3CFC) }
    static var arcGreen: UIColor { return UIColor(0x12A656) }
    static var arcRed: UIColor { return UIColor(0xE35641) }
    static var arcOrange: UIColor { return UIColor(0xEB781B) }

    // MARK: - Extra Colours

    static var arcRuby: UIColor { return UIColor(0xD85582) }
    static var arcByzantine: UIColor { return UIColor(0x8B408C) }
    static var arcMagenta: UIColor { return UIColor(0x8E1DD2) }
    static var arcJade: UIColor { return UIColor(0x079260) }
    static var arcJungle: UIColor { return UIColor(0x18A1B1) }
    static var arcYellow: UIColor { return UIColor(0xEEA10A) }
    static var arcGold: UIColor { return UIColor(0xAA9131) }
    static var arcBrown: UIColor { return UIColor(0xB4831D) }
    static var arcDarkBlue: UIColor { return UIColor(0x26398B) }
    static var arcBlue: UIColor { return UIColor(0x3B71F6) }
    static var arcLightBlue: UIColor { return UIColor(0x039FD4) }
    static var arcNavy: UIColor { return UIColor(0x4056B5) }
    static var arcSapphire: UIColor { return UIColor(0x4884AE) }
    static var arcAnchor: UIColor { return UIColor(0x4E5268) }
    static var arcSpaniard: UIColor { return UIColor(0x2D2F3E) }

    // MARK: - Alpha Variations

    var light: UIColor { return self.withAlphaComponent(0.32) }
    var extraLight: UIColor { return self.withAlphaComponent(0.2) }
    var extraExtraLight: UIColor { return self.withAlphaComponent(0.06) }

    // MARK: - Misc

    static var arcSelected: UIColor { return UIColor(0x9A217D) }

    static var arcRecordingOffRed: UIColor { return .arcRed }
    static var arcRecordingOnGreen: UIColor { return .arcGreen }

    static var toggleOn: UIColor { return arcPurple }
    static var toggleOff: UIColor { return UIColor(0xBCBCD2) }

    static var swarmOrange: UIColor { return UIColor(0xffa633) }

    static var systemBlue: UIColor { return UIButton(type: .system).tintColor }

    // MARK: - Activity Types

    static func color(for activityType: ActivityTypeName) -> UIColor {
        switch activityType {
        case .unknown:
            return .arcGray1
        case .bogus:
            return .arcBrown
        case .stationary:
            return .arcPurple
        case .walking, .golf, .wheelchair:
            return .arcGreen
        case .running:
            return .arcOrange
        case .cycling, .rowing, .swimming, .kayaking:
            return .arcLightBlue
        case .car, .taxi:
            return .arcAnchor
        case .bus:
            return .arcNavy
        case .motorcycle, .scooter:
            return .arcRed
        case .airplane:
            return .arcMagenta
        case .boat:
            return .arcBlue
        case .train, .metro, .tram, .cableCar, .funicular, .chairlift, .skiLift:
            return .arcGold
        case .tractor:
            return .arcSpaniard
        case .tuktuk, .songthaew:
            return .arcBrown
        case .skateboarding:
            return .arcJungle
        case .inlineSkating:
            return .arcRuby
        case .snowboarding:
            return .arcSapphire
        case .skiing:
            return .arcDarkBlue
        case .horseback:
            return .arcByzantine
        }
    }

    // MARK: - Hex init

    convenience init(_ hex: Int) {
        self.init(
            red: CGFloat((hex >> 16) & 0xff) / 255,
            green: CGFloat((hex >> 8) & 0xff) / 255,
            blue: CGFloat(hex & 0xff) / 255,
            alpha: 1
        )
    }

}

