//
//  Scraps.swift
//  Arc Mini
//
//  Created by Matt Greenfield on 24/3/20.
//  Copyright © 2020 Matt Greenfield. All rights reserved.
//

import UIKit
import Photos
import LocoKit

// fix back swipe navigation
extension UINavigationController: UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }
    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return viewControllers.count > 1
    }
}

extension String {
    func localised(comment: String = "") -> String {
        return NSLocalizedString(self, comment: comment)
    }

    func appendLineToURL(fileURL: URL) throws {
        try appendingFormat("\n").appendToURL(fileURL: fileURL)
    }

    func appendToURL(fileURL: URL) throws {
        let dataObj = data(using: String.Encoding.utf8)!
        try dataObj.appendToURL(fileURL)
    }
}

extension Data {
    func appendToURL(_ fileURL: URL) throws {
        if let fileHandle = try? FileHandle(forWritingTo: fileURL) {
            defer {
                fileHandle.closeFile()
            }
            fileHandle.seekToEndOfFile()
            fileHandle.write(self)
        } else {
            try write(to: fileURL, options: .atomic)
        }
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

extension PHAsset {
    func hasLocationInside(timelineItem: TimelineItem) -> Bool {
        guard let location = self.location else { return false }

        // test photo validity against the visit / path
        if timelineItem.contains(location, sd: 5) { return true }

        // test against the place
        if let place = (timelineItem as? ArcVisit)?.place {
            return place.contains(location: location)
        }

        return false
    }
}

extension ProcessInfo.ThermalState {
    var stringValue: String {
        switch self {
        case .nominal: return "nominal"
        case .fair: return "fair"
        case .serious: return "serious"
        case .critical: return "critical"
        @unknown default: return "@unknown"
        }
    }
}

extension ProcessInfo {
    // from Quinn the Eskimo at Apple
    // https://forums.developer.apple.com/thread/105088#357415
    var memoryFootprint: Measurement<UnitInformationStorage>? {
        // The `TASK_VM_INFO_COUNT` and `TASK_VM_INFO_REV1_COUNT` macros are too
        // complex for the Swift C importer, so we have to define them ourselves.
        let TASK_VM_INFO_COUNT = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        let TASK_VM_INFO_REV1_COUNT = mach_msg_type_number_t(MemoryLayout.offset(of: \task_vm_info_data_t.min_address)! / MemoryLayout<integer_t>.size)
        var info = task_vm_info_data_t()
        var count = TASK_VM_INFO_COUNT
        let kr = withUnsafeMutablePointer(to: &info) { infoPtr in
            infoPtr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), intPtr, &count)
            }
        }
        guard kr == KERN_SUCCESS, count >= TASK_VM_INFO_REV1_COUNT else { return nil }

        return Measurement<UnitInformationStorage>(value: Double(info.phys_footprint), unit: .bytes)
    }
}

extension FileManager {
    var iCloudDocsDir: URL? {
        guard let iCloudRoot = url(forUbiquityContainerIdentifier: nil) else { return nil }

        let docsDir = iCloudRoot.appendingPathComponent("Documents")

        if !fileExists(atPath: docsDir.path, isDirectory: nil) {
            do {
                try createDirectory(at: docsDir, withIntermediateDirectories: true, attributes: nil)

            } catch {
                logger.error("\(error)")
                return nil
            }
        }

        return docsDir
    }
}

