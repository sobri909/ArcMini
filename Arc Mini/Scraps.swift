//
//  Scraps.swift
//  Arc Mini
//
//  Created by Matt Greenfield on 24/3/20.
//  Copyright © 2020 Matt Greenfield. All rights reserved.
//

import UIKit

enum Weekday: Int, CaseIterable {
    case all = 0
    case sunday = 1
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6
    case saturday = 7
}

let greg = Calendar(identifier: Calendar.Identifier.gregorian)

extension Date {
    var weekday: Weekday { return Weekday(rawValue: greg.dateComponents([.weekday], from: self).weekday!)! }
}

extension String {
    func localised(comment: String = "") -> String {
        return NSLocalizedString(self, comment: comment)
    }
}

extension Bundle {
    static var buildNumber: Int {
        return Int(main.infoDictionary![kCFBundleVersionKey as String] as! String)!
    }
    static var versionNumber: String {
        return main.infoDictionary!["CFBundleShortVersionString"] as! String
    }
}

extension UIDevice {
    var modelCode: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let modelCode = withUnsafeMutablePointer(to: &systemInfo.machine) {
            ptr in String(cString: UnsafeRawPointer(ptr).assumingMemoryBound(to: CChar.self))
        }
        return modelCode
    }
}

extension URL {
    var queryPairs: [String: String]? {
        guard let query = query else { return nil }
        var queryStrings = [String: String]()
        for pair in query.components(separatedBy: "&") {
            let key = pair.components(separatedBy: "=")[0]
            let value = pair
                .components(separatedBy:"=")[1]
                .replacingOccurrences(of: "+", with: " ")
                .removingPercentEncoding ?? ""
            queryStrings[key] = value
        }
        return queryStrings
    }
}

// MARK: - GCD

func onMain(_ closure: @escaping () -> ()) {
    if Thread.isMainThread {
        closure()
    } else {
        DispatchQueue.main.async(execute: closure)
    }
}

func delay(_ delay: TimeInterval, closure: @escaping () -> ()) {
    DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: closure)
}

func background(qos: DispatchQoS.QoSClass? = nil, closure: @escaping () -> ()) {
    if let qos = qos {
        DispatchQueue.global(qos: qos).async(execute: closure)
    } else {
        DispatchQueue.global().async(execute: closure)
    }
}
