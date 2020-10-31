//
//  Array+ArcSample.swift
//  Arc
//
//  Created by Matt Greenfield on 16/10/20.
//  Copyright © 2020 Big Paua. All rights reserved.
//

import Gzip

extension Array where Element: ArcSample {
    
    func saveToBackups() {
        guard let backupsDir = Backups.backupsDir else { return }
        guard let filename = weekFilename else { return }
        
        // don't to wasteful saves
        guard needBackup else { return }
        
        let manager = FileManager.default
        let folderURL = backupsDir.appendingPathComponent("LocomotionSample", isDirectory: true)
        let fullURL = folderURL.appendingPathComponent(filename + ".json.gz")

        // create the dir if missing
        do { try manager.createDirectory(at: folderURL, withIntermediateDirectories: true, attributes: nil) }
        catch { logger.error("\(error)"); return }

        let encodingDate = Date()

        let json: Data
        do { json = try Backups.encoder.encode(self).gzipped(level: .bestCompression) }
        catch { logger.error("\(error)"); return }

        let files: [URL]
        do {
            files = try manager.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: [.ubiquitousItemDownloadingStatusKey])
        } catch {
            logger.error("\(error)")
            return
        }

        if let existing = files.first(where: { $0.lastPathComponent.contains(filename) }) { // existing file
            if existing.lastPathComponent.hasSuffix("icloud") {
                print("DOWNLOADING: \(filename)")
                do { try manager.startDownloadingUbiquitousItem(at: existing) }
                catch { logger.error("\(error)") }
                return
            }

            let document = ArcDocument(fileURL: fullURL)

            document.open { success in
                guard success else {
                    logger.error("Failed to open existing file: \(existing.absoluteString)")
                    return
                }

                document.data = json
                document.updateChangeCount(.done)

                document.close { success in
                    if !success { logger.error("document.close() failed"); return }
                    for sample in self { sample.backupLastSaved = encodingDate }
                }
            }

        } else { // new file
            let tempFile = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(filename)

            do {
                // delete previous temp file if it's already there
                if manager.fileExists(atPath: tempFile.path) {
                    try manager.removeItem(at: tempFile)
                }

                // write out the temp file
                try json.write(to: tempFile)

                // move it to iCloud Drive
                try manager.setUbiquitous(true, itemAt: tempFile, destinationURL: fullURL)

                // success
                for sample in self { sample.backupLastSaved = encodingDate }

            } catch {
                logger.error("\(error)")
            }
        }
    }
    
    var needBackup: Bool {
        guard let weekFilename = weekFilename else { print("weekFilename == nil! WTF"); return false }
        
        for sample in self {
            guard let lastSaved = sample.lastSaved else { continue }

            // never been backed up?
            guard let backupLastSaved = sample.backupLastSaved else { return true }

            // db version is newer than backup?
            if backupLastSaved < lastSaved { return true }
        }
        
        print("week: \(weekFilename) needBackup: FALSE")
        
        return false
    }

    var weekFilename: String? {
        guard let first = first else { return nil }
        return Backups.weekFormatter.string(from: first.date)
    }
    
}
