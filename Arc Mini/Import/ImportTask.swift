//
//  ImportTask.swift
//  Arc
//
//  Created by Matt Greenfield on 19/3/21.
//  Copyright © 2021 Big Paua. All rights reserved.
//

import Foundation

struct ImportTask {
    
    let filename: String
    var url: URL
    var state: ImportState = .created {
        didSet {
            if deleteOnFinish, state == .finished {
                deleteFile()
            }
        }
    }
    var deleteOnFinish: Bool = false
    private(set) var fileType: FileType = .unknown

    // MARK: -
    
    init(filename: String, url: URL) {
        self.filename = filename
        self.url = url
        
        let bits = url.deletingLastPathComponent().absoluteString.split(separator: "/")
        
        if let dir = bits.last, let type = typeFrom(dirName: dir) {
            fileType = type
            
        } else if let dir = bits.dropLast().last, let type = typeFrom(dirName: dir) {
            fileType = type

        } else {
            print("bits: \(bits)")
            fatalError("FUCK")
        }
    }
    
    func typeFrom(dirName: Substring) -> FileType? {
        switch dirName {
        case "LocomotionSample":
            return .samples
        case "TimelineItem":
            return .item
        case "Place":
            return .item
        case "Note":
            return .note
        case "TimelineRangeSummary":
            return .summary
        default:
            return nil
        }
    }

    // MARK: -
    
    var totalSamples: Int? = 0
    var importedSamples = 0
    var existingSamples = 0
    var deferredSamples = 0
    var erroredSamples = 0
    
    var downloadingDependents: Set<URL> = []
    var errors: [Error] = []

    // MARK: -
    
    var canRedoWithoutDependents: Bool {
        if errors.isEmpty { return false }
        for error in errors {
            if (error as? ArcError)?.errorCode == .missingDependentFile {
                return true
            }
        }
        return false 
    }
    
    // MARK: -
    
    func deleteFile() {
        print("deleteFile(): \(url.tidyiCloudFilename)")
        
        let coordinator = NSFileCoordinator(filePresenter: nil)
        coordinator.coordinate(writingItemAt: url, options: .forDeleting, error: nil) { url in
            do {
                try FileManager.default.removeItem(at: url)
                print("FINISHED AND DELETED: \(url.tidyiCloudFilename)")
            } catch {
                logger.error(error, subsystem: .backups)
            }
        }
    }
    
    mutating func reset() {
        importedSamples = 0
        existingSamples = 0
        deferredSamples = 0
        erroredSamples = 0
        errors.removeAll()
    }
    
    // MARK: -
    
    var progress: Double {
        guard let total = totalSamples else { return 0 }
        return Double(importedSamples + existingSamples + deferredSamples + erroredSamples) / Double(total)
    }
    
    func printProgress() {
        onMain {
            print("progress: \(String(format: "%6.2f", progress * 100))% (imported: \(importedSamples), existing: \(existingSamples), deferred: \(deferredSamples), errored: \(erroredSamples))")
        }
    }
    
    // MARK: - Enums
    
    enum ImportState: String {
        case created, queued, downloading, opening, importing, waiting, finished, errored
        var isActive: Bool {
            switch self {
            case .queued, .downloading, .opening, .importing:
                return true
            default:
                return false
            }
        }
    }
    
    enum FileType: String {
        case samples, item, place, note, summary, unknown
    }
    
}
