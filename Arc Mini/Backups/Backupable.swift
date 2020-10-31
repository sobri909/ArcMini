//
//  Backupable.swift
//  Arc
//
//  Created by Matt Greenfield on 5/10/20.
//  Copyright © 2020 Big Paua. All rights reserved.
//

import LocoKit

protocol Backupable: TimelineObject {
    var backupLastSaved: Date? { get set }
    static var backupFolderPrefixLength: Int { get }
    
    func backup()
    func saveNoDate()
}

extension Backupable {
    
    var needToBackup: Bool {
        // don't backup if it hasn't been saved to SQLite yet
        guard let lastSaved = lastSaved else { return false }

        // needs backup if never been backed up before
        guard let backupLastSaved = backupLastSaved else { return true }
        
        // backup out of date?
        if backupLastSaved < lastSaved { return true }

        return false
    }
   
    func backup() {
        guard needToBackup else { return }
        guard let backupsDir = Backups.backupsDir else { return }

        let manager = FileManager.default
        let filename = objectId.uuidString + ".json"
        var folderURL = backupsDir.appendingPathComponent(Self.databaseTableName, isDirectory: true)
        if Self.backupFolderPrefixLength > 0 {
            folderURL.appendPathComponent(String(objectId.uuidString.prefix(Self.backupFolderPrefixLength)), isDirectory: true)
        }
        let fullURL = folderURL.appendingPathComponent(filename)

        // create the dir if missing
        do { try manager.createDirectory(at: folderURL, withIntermediateDirectories: true, attributes: nil) }
        catch { logger.error("\(error)"); return }

        let encodingDate = Date()

        let json: Data
        do { json = try Backups.encoder.encode(ConcreteBackupable(object: self)) }
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
                    self.backupLastSaved = encodingDate
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
                backupLastSaved = encodingDate

            } catch {
                logger.error("\(error)")
            }
        }
    }

}
