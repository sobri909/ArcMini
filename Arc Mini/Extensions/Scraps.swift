//
//  Scraps.swift
//  Arc Mini
//
//  Created by Matt Greenfield on 24/3/20.
//  Copyright © 2020 Matt Greenfield. All rights reserved.
//

import UIKit

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
