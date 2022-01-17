//
//  ArcImporter.swift
//  Arc
//
//  Created by Matt Greenfield on 2/2/19.
//  Copyright © 2019 Big Paua. All rights reserved.
//

import Foundation
import LocoKit
import Combine
import SwiftNotes

class ArcImporter: ObservableObject {
    
    static let highlander = ArcImporter()

    private let manager = FileManager.default
    private let store = RecordingManager.store
    
    // MARK: -

    private init() {
        // we want restores paused while primary queue is busy
        Jobs.highlander.managedQueues.append(importQueue)
        
        when(.NSMetadataQueryDidFinishGathering) { note in
            print("NSMetadataQueryDidFinishGathering")

            if !self.updatingFileLists {
                self.updateFileLists()
                if self.doingManagedRestore {
                    Self.startManagedRestore()
                }
                
            } else {
                DispatchQueue.main.asyncDeduped(target: ArcImporter.highlander, after: 60) {
                    self.updateFileLists()
                    if self.doingManagedRestore {
                        Self.startManagedRestore()
                    }
                }
            }
        }
        
        when(.NSMetadataQueryDidUpdate) { note in
            print("NSMetadataQueryDidUpdate")
            
            if !self.updatingFileLists {
                DispatchQueue.main.asyncDeduped(target: ArcImporter.highlander, after: 60) {
                    self.updateFileLists()
                    self.downloadOriginRestoreDir()
                }
            }
        }
        
        // need to stop file watching, because it leaks proper nasty
        when(UIApplication.didEnterBackgroundNotification) { _ in
            self.stopWatchingFiles()
        }
        
        when(UIApplication.didBecomeActiveNotification) { _ in
            if self.tasksDownloading > 0 || self.restoreDownloading > 0 {
                self.startWatchingFiles()
            }
        }
        
        tasksObserver = $importTasks
            .debounce(for: 2, scheduler: DispatchQueue.main)
            .sink { self.updateTaskCounts(tasksCopy: $0) }
    }
    
    // MARK: -
    
    var haveActiveTasks: Bool {
        for task in importTasks.values {
            if task.state.isActive { return true }
        }
        return false
    }
    
    // MARK: - Import tasks

    @Published public private(set) var missing: [UUID] = []
    @Published public private(set) var importTasks: Dictionary<String, ImportTask> = [:]
    
    func importTask(for url: URL, createIfMissing: Bool = false) -> ImportTask? {
        let filename = url.tidyiCloudFilename
        if let existing = importTasks[filename] { return existing }
        if !createIfMissing { return nil }
        let task = ImportTask(filename: filename, url: url)
        onMain { self.importTasks[filename] = task }
        return task
    }
    
    func importTask(for uuid: UUID) -> ImportTask? {
        return importTasks[uuid.uuidString + ".json"]
    }
    
    func updateImportTask(_ task: ImportTask) {
        onMain { self.importTasks[task.filename] = task }
    }
    
    // MARK: - Task statistics
    
    @Published public var totalSampleWeekTasks = 0
    @Published public var totalNoteTasks = 0
    @Published public var totalSummaryTasks = 0
    @Published public var finishedSampleWeekTasks = 0
    @Published public var finishedNoteTasks = 0
    @Published public var finishedSummaryTasks = 0
    @Published public var tasksDownloading = 0
    @Published public var restoreDownloading = 0
    @Published public var totalErrors = 0
    
    private var totalRemainingTasks: Int {
        let remainingSamples = totalSampleWeekTasks - finishedSampleWeekTasks
        let remainingNotes = totalNoteTasks - finishedNoteTasks
        let remainingSummaries = totalSummaryTasks - finishedSummaryTasks
        print("remainingSamples: \(remainingSamples), remainingNotes: \(remainingNotes), remainingSummaries: \(remainingSummaries)")
        return remainingSamples + remainingNotes + remainingSummaries
    }

    private var tasksObserver: AnyCancellable?

    private func updateTaskCounts(tasksCopy: Dictionary<String, ImportTask>) {
        inBackground {
            print("updateTaskCounts()")
            let totalSamples = tasksCopy.values.filter { $0.fileType == .samples }.count
            let totalNotes = tasksCopy.values.filter { $0.fileType == .note }.count
            let totalSummaries = tasksCopy.values.filter { $0.fileType == .summary }.count
            let finishedSamples = tasksCopy.values.filter { $0.fileType == .samples && $0.state == .finished }.count
            let finishedNotes = tasksCopy.values.filter { $0.fileType == .note && $0.state == .finished }.count
            let finishedSummaries = tasksCopy.values.filter { $0.fileType == .summary && $0.state == .finished }.count
            let tasksDownloading = tasksCopy.values.filter { $0.state == .downloading }.count
            let totalErrors = tasksCopy.values.reduce(0, { $0 + $1.errors.count })
            onMain {
                self.totalSampleWeekTasks = totalSamples
                self.totalNoteTasks = totalNotes
                self.totalSummaryTasks = totalSummaries
                self.finishedSampleWeekTasks = finishedSamples
                self.finishedNoteTasks = finishedNotes
                self.finishedSummaryTasks = finishedSummaries
                self.tasksDownloading = tasksDownloading
                self.restoreDownloading = self.downloadingOriginRestoreFiles.count
                self.totalErrors = totalErrors
                
                if self.tasksDownloading > 0 || self.restoreDownloading > 0 {
                    self.startWatchingFiles()
                } else {
                    self.stopWatchingFiles()
                    
                    if self.doingManagedRestore, !self.importTasks.isEmpty, self.totalRemainingTasks == 0 {
                        delay(3) { self.finishManagedRestore() }
                    }
                }
            }
        }
    }

    // MARK: - Importing
    
    public func importData(from url: URL) {
        if url.absoluteString.contains("/LocomotionSample/") {
            importSamples(from: url)
        } else if url.absoluteString.contains("/Note/") {
            importNote(from: url)
        } else if url.absoluteString.contains("/TimelineRangeSummary/") {
            importSummary(from: url)
        }
    }
    
    public func importSamples(from url: URL, ignoringMissingDependents: Bool = false, deleteOnFinish: Bool = false) {
        var task = importTask(for: url, createIfMissing: true)!
        
        task.reset()
        task.state = .queued
        task.deleteOnFinish = deleteOnFinish
        updateImportTask(task)

        importQueue.addOperation { [self] in
            store.connectToDatabase()

            // in background need to be gentle
            if LocomotionManager.highlander.applicationState == .active {
                importQueue.qualityOfService = .utility
            } else {
                importQueue.qualityOfService = .background
            }
            
            // needs downloading first?
            if url.lastPathComponent.hasSuffix("icloud") {
                if task.state == .downloading { return }

                logger.info("Downloading: \(url.lastPathComponent)", subsystem: .backups)
                do {
                    try FileManager.default.startDownloadingUbiquitousItem(at: url)
                    task.state = .downloading
                    updateImportTask(task)
                } catch {
                    task.errors.append(error)
                    updateImportTask(task)
                    logger.error(error, subsystem: .backups)
                }
                return
            }
            
            task.state = .opening
            updateImportTask(task)
            
            do {
                var jsonData: Data
                if url.lastPathComponent.hasSuffix("gz") {
                    jsonData = try Data(contentsOf: url).gunzipped()
                } else {
                    jsonData = try Data(contentsOf: url)
                }
                
                print("GOT jsonData: \(jsonData)")
                
                let samples = try Backups.decoder.decode(Array<ArcSample>.self, from: jsonData)
                
                print("GOT samples: \(samples.count)")
                
                task.totalSamples = samples.count
                task.state = .importing
                updateImportTask(task)

                for sample in samples {
                    if task.importedSamples > 0 || task.erroredSamples > 0 || task.deferredSamples > 0 {
                        task.printProgress()
                    }
                    
                    if let existing = store.sample(for: sample.sampleId) {
                        // can't overwrite existing without a lastSaved
                        guard let importLastSaved = sample.lastSaved else {
                            task.existingSamples += 1
                            updateImportTask(task)
                            continue
                        }
                        
                        // can't overwrite existing if the import object isn't newer than existing
                        if let existingLastSaved = existing.lastSaved, existingLastSaved >= importLastSaved {
                            task.existingSamples += 1
                            updateImportTask(task)
                            continue
                        }
                        
                        // updating existing object
                        existing.invalidate()
                        sample.hasChanges = true

                    } else { // nil lastSaved = new object, so will be inserted instead of updated
                        sample.lastSaved = nil
                    }
                    
                    // if it's not an orphan sample, make sure the item is existing / imported first
                    if let itemId = sample.timelineItemId, store.item(for: itemId) == nil {
                        
                        // item file is downloading? then need to skip for now
                        if task.downloadingDependents.first(where: { $0.absoluteString.contains(itemId.uuidString) }) != nil {
                            task.deferredSamples += 1
                            updateImportTask(task)
                            continue
                        }
                        
                        // item file is missing? well, shit
                        if missing.contains(itemId) {
                            
                            // don't care that the item file is missing?
                            if ignoringMissingDependents {
                                sample.timelineItemId = nil
                                
                            } else { // do care
                                task.erroredSamples += 1
                                updateImportTask(task)
                                continue
                            }
                            
                            // have an item file?
                        } else if let itemURL = itemFiles.first(where: { $0.absoluteString.contains(itemId.uuidString) }) {
                            do {
                                guard try importItem(from: itemURL) else {
                                    task.downloadingDependents.insert(itemURL)
                                    task.deferredSamples += 1
                                    updateImportTask(task)
                                    continue
                                }
                            } catch {
                                logger.error(error, subsystem: .backups)
                                task.erroredSamples += 1
                                task.errors.append(error)
                                updateImportTask(task)
                                continue
                            }
                            
                            // no item file, but don't care?
                        } else if ignoringMissingDependents {
                            sample.timelineItemId = nil
                            
                        } else {
                            logger.error("Missing item file: \(itemId.uuidString)", subsystem: .backups)
                            task.erroredSamples += 1
                            task.errors.append(ArcError(code: .missingDependentFile, description: "Missing item file: \(itemId.uuidString)"))
                            updateImportTask(task)
                            onMain { missing.append(itemId) }
                            continue
                        }
                    }
                    
                    sample.store = store
                    store.add(sample)
                    sample.save()
                    
                    task.importedSamples += 1
                    updateImportTask(task)
                }
                
                print("FINI")
                
                // first date might've changed
                onMain { AppDelegate.timelineController?.calendar = nil }
                
                if task.erroredSamples > 0 {
                    task.state = .errored
                } else if task.deferredSamples > 0 {
                    task.state = .waiting
                } else {
                    task.state = .finished
                }
                updateImportTask(task)

            } catch {
                logger.error(error, subsystem: .backups)
                task.state = .errored
                task.errors.append(error)
                updateImportTask(task)
            }
        }
    }
    
    // returns true on successful import
    @discardableResult
    public func importItem(from url: URL) throws -> Bool {
        var task = importTask(for: url, createIfMissing: true)!

        // needs downloading first?
        if url.lastPathComponent.hasSuffix("icloud") {
            if task.state == .downloading { return false }

            logger.info("Downloading: \(url.lastPathComponent)", subsystem: .backups)
            do {
                try FileManager.default.startDownloadingUbiquitousItem(at: url)
                task.state = .downloading
                updateImportTask(task)
            } catch {
                task.state = .errored
                task.errors.append(error)
                updateImportTask(task)
                throw error
            }
            return false
        }
        
        task.state = .importing
        updateImportTask(task)

        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            task.state = .errored
            updateImportTask(task)
            throw error
        }

        let item: ArcItem
        do {
            item = try itemFor(data: data)
            
        } catch {
            task.state = .errored
            updateImportTask(task)
            throw error
        }
        
        // if it's got a placeId, make sure the place is existing / imported first
        if let visit = item as? ArcVisit {
            if let placeId = visit.placeId, store.place(for: placeId) == nil {
                
                // place file is missing? well, shit
                if missing.contains(placeId) {
                    task.state = .errored
                    updateImportTask(task)
                    return false
                }
                
                // place file is downloading? then need to skip for now
                if let placeTask = importTask(for: placeId), placeTask.state == .downloading {
                    task.state = .waiting
                    updateImportTask(task)
                    return false
                }
                
                if let placeURL = placeFiles.first(where: { $0.absoluteString.contains(placeId.uuidString) }) {

                    // can't import the place? can't import the item
                    do {
                        guard let place = try importPlace(from: placeURL) else {
                            task.downloadingDependents.insert(placeURL)
                            updateImportTask(task)
                            return false
                        }

                        // above might have returned a different (but matching) place, ie Foursquare match
                        if visit.placeId != place.placeId { print("existing Place doesn't match imported.placeId, so reassigning") }
                        visit.placeId = place.placeId

                    } catch {
                        logger.error(error, subsystem: .backups)
                        task.state = .errored
                        task.errors.append(error)
                        updateImportTask(task)
                        return false
                    }

                } else {
                    onMain { self.missing.append(placeId) }
                    task.state = .errored
                    updateImportTask(task)
                    throw ArcError(code: .missingDependentFile, description: "Missing place file: \(placeId.uuidString)")
                }
            }
        }

        if let existing = store.item(for: item.itemId) {
            // can't overwrite existing without a lastSaved
            guard let importLastSaved = item.lastSaved else {
                task.state = .errored
                task.errors.append(ArcError(code: .misc, description: "Can't update existing TimelineItem because importedItem.lastSaved == nil"))
                updateImportTask(task)
                return false
            }
            
            // can't overwrite existing if the import object isn't newer than existing
            if let existingLastSaved = existing.lastSaved, existingLastSaved >= importLastSaved {
                task.state = .finished
                updateImportTask(task)
                return false
            }
            
            // updating existing object
            existing.invalidate()
            item.hasChanges = true
            
        } else { // nil lastSaved = new object, so will be inserted instead of updated
            item.lastSaved = nil
        }
        
        // break edges, to avoid foreign key fails
        item.breakEdges()

        item.store = store
        store.add(item)
        item.save(immediate: true)

        task.state = .finished
        updateImportTask(task)
        
        // fix the calendar view
        Settings._firstTimelineItem = nil
        
        logger.info("IMPORTED ITEM: \(item.title) (\(item.itemId.uuidString))", subsystem: .backups)
        
        return true
    }
    
    private func itemFor(data: Data) throws -> ArcItem {
        do {
            return try Backups.decoder.decode(ArcPath.self, from: data)
        } catch {
            if error is DecodeError { // will be "trying to decode path as visit", which is expected here
                return try Backups.decoder.decode(ArcVisit.self, from: data)
            } else {
                throw error
            }
//            if (error as? ArcError)?.errorCode == .missingDependentFile { throw error }
        }
    }
    
    // returns the Place on successful import or found existing
    @discardableResult
    public func importPlace(from url: URL) throws -> Place? {
        var task = importTask(for: url, createIfMissing: true)!

        // needs downloading first?
        if url.lastPathComponent.hasSuffix("icloud") {
            if task.state == .downloading { return nil }

            logger.info("Downloading: \(url.lastPathComponent)", subsystem: .backups)
            do {
                try FileManager.default.startDownloadingUbiquitousItem(at: url)
                task.state = .downloading
                updateImportTask(task)
            } catch {
                task.state = .errored
                task.errors.append(error)
                updateImportTask(task)
                throw error
            }
            return nil
        }
        
        task.state = .importing
        updateImportTask(task)
        
        guard let data = try? Data(contentsOf: url) else {
            logger.error("Couldn't get data from Place JSON file", subsystem: .backups)
            task.state = .errored
            task.errors.append(ArcError(code: .misc, description: "Couldn't get data from Place JSON file"))
            updateImportTask(task)
            return nil
        }
        
        do {
            let place = try Backups.decoder.decode(Place.self, from: data)
            
            if let existing = store.place(for: place.placeId) {
                // can't overwrite existing without a lastSaved
                guard let importLastSaved = place.lastSaved else {
                    task.state = .errored
                    task.errors.append(ArcError(code: .misc, description: "Can't update existing Place because importedPlace.lastSaved == nil"))
                    updateImportTask(task)
                    return nil
                }
                
                // can't overwrite existing if the import object isn't newer than existing
                if let existingLastSaved = existing.lastSaved, existingLastSaved >= importLastSaved {
                    task.state = .finished
                    updateImportTask(task)
                    return nil
                }
                
                // updating existing object
                existing.invalidate()
                place.hasChanges = true

            } else if let venueId = place.foursquareVenueId, let existing = store.place(foursquareVenueId: venueId) {
                task.state = .finished
                updateImportTask(task)
                return existing // found an existing one based on foursquareVenueId match, so return that
                
            } else { // nil lastSaved = new object, so will be inserted instead of updated
                place.lastSaved = nil
            }
            
            store.add(place)
            place.save(immediate: true)
            
            task.state = .finished
            updateImportTask(task)
            
            logger.info("IMPORTED PLACE: \(place.name)", subsystem: .backups)

            return place
            
        } catch {
            logger.error(error, subsystem: .backups)
            task.state = .errored
            task.errors.append(error)
            updateImportTask(task)
            return nil
        }
    }
    
    public func importNote(from url: URL, deleteOnFinish: Bool = false) {
        var task = importTask(for: url, createIfMissing: true)!
        
        task.deleteOnFinish = deleteOnFinish
        updateImportTask(task)
        
        importQueue.addOperation { [self] in
            store.connectToDatabase()
            
            // needs downloading first?
            if url.lastPathComponent.hasSuffix("icloud") {
                if task.state == .downloading { return }

                logger.info("Downloading: \(url.lastPathComponent)", subsystem: .backups)
                do {
                    try FileManager.default.startDownloadingUbiquitousItem(at: url)
                    task.state = .downloading
                    updateImportTask(task)
                } catch {
                    task.state = .errored
                    task.errors.append(error)
                    updateImportTask(task)
                    logger.error(error, subsystem: .backups)
                }
                return
            }
            
            task.state = .importing
            updateImportTask(task)

            guard let data = try? Data(contentsOf: url) else {
                logger.error("Couldn't get data from Note JSON file", subsystem: .backups)
                task.state = .errored
                task.errors.append(ArcError(code: .misc, description: "Couldn't get data from Note JSON file"))
                updateImportTask(task)
                return
            }
            
            do {
                let note = try Backups.decoder.decode(Note.self, from: data)
                
                if let existing = store.note(for: note.noteId) {
                    // can't overwrite existing without a lastSaved
                    guard let importLastSaved = note.lastSaved else {
                        task.state = .errored
                        task.errors.append(ArcError(code: .misc, description: "Can't update existing Note because importedNote.lastSaved == nil"))
                        updateImportTask(task)
                        return
                    }
                    
                    // can't overwrite existing if the import object isn't newer than existing
                    if let existingLastSaved = existing.lastSaved, existingLastSaved >= importLastSaved {
                        task.state = .finished
                        updateImportTask(task)
                        return
                    }
                    
                    // updating existing object
                    existing.invalidate()
                    note.hasChanges = true

                } else { // nil lastSaved = new object, so will be inserted instead of updated
                    note.lastSaved = nil
                }
                
                store.add(note)
                note.save(immediate: true)

                task.state = .finished
                updateImportTask(task)
                
                logger.info("IMPORTED NOTE: \(note.date)", subsystem: .backups)
                
            } catch {
                logger.error(error, subsystem: .backups)
                task.state = .errored
                task.errors.append(error)
                updateImportTask(task)
            }
        }
    }
    
    public func importSummary(from url: URL, deleteOnFinish: Bool = false) {
        var task = importTask(for: url, createIfMissing: true)!
        
        task.deleteOnFinish = deleteOnFinish
        updateImportTask(task)
        
        importQueue.addOperation { [self] in
            store.connectToDatabase()

            // needs downloading first?
            if url.lastPathComponent.hasSuffix("icloud") {
                if task.state == .downloading { return }

                logger.info("Downloading: \(url.lastPathComponent)", subsystem: .backups)
                do {
                    try FileManager.default.startDownloadingUbiquitousItem(at: url)
                    task.state = .downloading
                    updateImportTask(task)
                } catch {
                    task.state = .errored
                    task.errors.append(error)
                    updateImportTask(task)
                    logger.error(error, subsystem: .backups)
                }
                return
            }
            
            task.state = .importing
            updateImportTask(task)

            guard let data = try? Data(contentsOf: url) else {
                logger.error("Couldn't get data from Summary JSON file", subsystem: .backups)
                task.state = .errored
                task.errors.append(ArcError(code: .misc, description: "Couldn't get data from Summary JSON file"))
                updateImportTask(task)
                return
            }
            
            do {
                let summary = try Backups.decoder.decode(TimelineRangeSummary.self, from: data)
                
                // find existing based on objectId
                if let existing = store.timelineSummary(for: summary.summaryId) {
                    // can't overwrite existing without a lastSaved
                    guard let importLastSaved = summary.lastSaved else {
                        print("summary.lastSaved == nil")
                        task.state = .errored
                        updateImportTask(task)
                        task.state = .errored
                        task.errors.append(ArcError(code: .misc, description: "Can't update existing Summary because importedSummary.lastSaved == nil"))
                        updateImportTask(task)
                        return
                    }
                    
                    // can't overwrite existing if the import object isn't newer than existing
                    if let existingLastSaved = existing.lastSaved, existingLastSaved >= importLastSaved {
                        task.state = .finished
                        updateImportTask(task)
                        return
                    }
                    
                    // updating existing object
                    existing.invalidate()
                    summary.hasChanges = true
                    
                } else { // nil lastSaved = new object, so will be inserted instead of updated
                    summary.lastSaved = nil
                    
                    // if it's a favourite day, check for existing based on dateRange, set it to favourite, then we done
                    if let existing = store.timelineSummary(for: summary.dateRange) {
                        print("found existing summary on dateRange match")
                        if summary.isFavourite {
                            logger.info("Updating existing summary to isFavourite = true", subsystem: .backups)
                            existing.isFavourite = true
                            existing.save()
                        }
                        task.state = .finished
                        updateImportTask(task)
                        return
                    }
                }
                
                store.add(summary)
                summary.save(immediate: true)

                task.state = .finished
                updateImportTask(task)
                
                logger.info("IMPORTED SUMMARY: \(summary.dateRange)", subsystem: .backups)

            } catch {
                logger.error(error, subsystem: .backups)
                task.state = .errored
                task.errors.append(error)
                updateImportTask(task)
            }
        }
    }
    
    // MARK: - Managed restore
    
    @Published var copyingRestoreFolder = false
    @Published var doingManagedRestore = false
    @Published var finishedManageRestore = false
    @Published var collatingFilesToDownload = false
    @Published var downloadingOriginRestoreFiles: Set<String> = []
    
    // MARK: -
    
    public static func startManagedRestore() {
        print("startManagedRestore()")
        highlander.doingManagedRestore = true
        inBackground {
            if !highlander.restoreDirExists {
                highlander.downloadOriginRestoreDir()
            }
            if highlander.downloadingOriginRestoreFiles.isEmpty {
                highlander.copyRestoreToImportDir()
                onMain { ArcImporter.highlander.updateFileLists() }
            }
        }
    }
    
    public var restoreDirExists: Bool {
        guard let restoreDir = restoreDir else { return false }
        return FileManager.default.fileExists(atPath: restoreDir.path)
    }
    
    private func downloadOriginRestoreDir() {
        guard let urlString = Settings.highlander[.possibleRestoreDir] as? String else { return }
        guard let dir = URL(string: urlString) else { return }
        guard let enumerator = manager.enumerator(at: dir, includingPropertiesForKeys: []) else { return }
        
        onMain { self.collatingFilesToDownload = true }

        var needsDownload: [URL] = []
        while let url = enumerator.nextObject() as? URL {
            if url.absoluteString.hasSuffix(".icloud") {
                needsDownload.append(url)
            } else {
                onMain {
                    if self.downloadingOriginRestoreFiles.contains(url.tidyiCloudFilename) {
                        logger.info("DOWNLOADED: \(url.tidyiCloudFilename)")
                    }
                    self.downloadingOriginRestoreFiles.remove(url.tidyiCloudFilename)
                }
            }
        }
        
        logger.info("QUEUEING DOWNLOADS: \(needsDownload.count) files", subsystem: .backups)
        
        var i = 0
        while i < needsDownload.count {
            var j = 0
            autoreleasepool {
                while j < 400 {
                    guard i < needsDownload.count else { break }
                    let url = needsDownload[i]
                    if !self.downloadingOriginRestoreFiles.contains(url.tidyiCloudFilename) {
                        do {
                            try manager.startDownloadingUbiquitousItem(at: url)
                            onMain { self.downloadingOriginRestoreFiles.insert(url.tidyiCloudFilename) }
                        }
                        catch { logger.error(error, subsystem: .backups) }
                    }
                    j += 1
                    i += 1
                }
            }
            print("i: \(i)")
            onMain { self.restoreDownloading = self.downloadingOriginRestoreFiles.count }
        }
        
        logger.info("QUEUED DOWNLOADS: \(needsDownload.count) files", subsystem: .backups)
        
        onMain {
            self.collatingFilesToDownload = false
            self.updateTaskCounts(tasksCopy: self.importTasks)
        }
    }
    
    private func copyRestoreToImportDir() {
        if restoreDirExists { logger.info("Restore dir already exists", subsystem: .backups); return }
        guard let urlString = Settings.highlander[.possibleRestoreDir] as? String else { return }
        guard let from = URL(string: urlString) else { return }
        guard let to = restoreDir else { return }
        
        print("copyRestoreToImportDir()")
        print("FROM: \(from)")
        print("  TO: \(to)")
        
        onMain { self.copyingRestoreFolder = true }
        
        let coordinator = NSFileCoordinator(filePresenter: nil)
        coordinator.coordinate(readingItemAt: from, options: [], error: nil) { url in
            do {
                try FileManager.default.copyItem(at: from, to: to)
                logger.info("Moved backup files to Import/Restore", subsystem: .backups)
                Settings.highlander[.possibleRestoreDir] = nil
            } catch {
                logger.error(error, subsystem: .backups)
            }
            onMain { self.copyingRestoreFolder = false }
        }
    }
    
    private func updateQueuedSampleFiles() {
        print("updateQueuedSampleFiles() sampleFiles: \(sampleFiles.count)")
        for url in sampleFiles {
            let taskState = importTask(for: url)?.state ?? .created
            if taskState == .created {
                print("updateQueuedSampleFiles() queued: \(url.tidyiCloudFilename)")
                importSamples(from: url, ignoringMissingDependents: true, deleteOnFinish: true)
            } else {
                print("updateQueuedSampleFiles() not queued (taskState: \(taskState))")
            }
        }
    }

    private func updateQueuedNoteFiles() {
        print("updateQueuedNoteFiles() noteFiles: \(noteFiles.count)")
        for url in noteFiles {
            let taskState = importTask(for: url)?.state ?? .created
            if taskState == .created {
                print("updateQueuedNoteFiles() queued: \(url.tidyiCloudFilename)")
                importNote(from: url, deleteOnFinish: true)
            } else {
                print("updateQueuedNoteFiles() not queued (taskState: \(taskState))")
            }
        }
    }

    private func updateQueuedSummaryFiles() {
        print("updateQueuedSummaryFiles() summaryFiles: \(summaryFiles.count)")
        for url in summaryFiles {
            let taskState = importTask(for: url)?.state ?? .created
            if taskState == .created {
                print("updateQueuedSummaryFiles() queued: \(url.tidyiCloudFilename)")
                importSummary(from: url, deleteOnFinish: true)
            } else {
                print("updateQueuedSummaryFiles() not queued (taskState: \(taskState))")
            }
        }
    }
    
    private func finishManagedRestore() {
        guard totalRemainingTasks == 0 else {  print("finishManagedRestore() CAN'T FINISH - HAVE TASKS"); return }

        print("finishManagedRestore()")

        doingManagedRestore = false
        finishedManageRestore = true
        Settings.highlander[.possibleRestoreDir] = nil
        
        if let restoreDir = restoreDir {
            let coordinator = NSFileCoordinator(filePresenter: nil)
            coordinator.coordinate(writingItemAt: restoreDir, options: .forDeleting, error: nil) { url in
                do {
                    try FileManager.default.removeItem(at: restoreDir)
                    print("DELETED RESTORE DIR")
                } catch {
                    logger.error(error, subsystem: .backups)
                }
            }
        }
    }
    
    func makeErrorsLog() -> String {
        var log = ""
        for (filename, task) in importTasks where !task.errors.isEmpty {
            log += "\n\(filename) (\(task.fileType))\n=== === === ===\n"
            for error in task.errors {
                log += "\(error)\n---\n"
            }
            log += "\n\n"
        }
        return log
    }
    
    // MARK: -
    
    private var restoreDir: URL? {
        return ArcImporter.highlander.importDir?.appendingPathComponent("Restore", isDirectory: true)
    }

    // MARK: - File lists
    
    @Published public private(set) var updatingFileLists = false
    @Published public private(set) var rootFiles: [URL] = []
    @Published public private(set) var itemFiles: [URL] = []
    @Published public private(set) var sampleFiles: [URL] = []
    @Published public private(set) var placeFiles: [URL] = []
    @Published public private(set) var noteFiles: [URL] = []
    @Published public private(set) var summaryFiles: [URL] = []

    // MARK: -
    
    public func updateFileLists() {
        guard let importDir = importDir else { return }
        if updatingFileLists { return }
        
        print("updateFileLists()")
        
        updatingFileLists = true
        
        do { // create the Import dir if missing
            try manager.createDirectory(at: importDir, withIntermediateDirectories: true, attributes: nil)
        } catch {
            logger.error(error, subsystem: .backups)
        }
        
        do { // files direcly in Import root
            let unfiltered = try manager.contentsOfDirectory(at: importDir, includingPropertiesForKeys: [])
            rootFiles = unfiltered.filter { !$0.hasDirectoryPath }.sorted { $0.path > $1.path }
        } catch {
            logger.error(error, subsystem: .backups)
        }
        
        importQueue.addOperation { self.updatePlaceFiles() }
        importQueue.addOperation { self.updateItemFiles() }
        importQueue.addOperation { self.updateSampleFiles() }
        importQueue.addOperation { self.updateNoteFiles() }
        importQueue.addOperation { self.updateSummaryFiles() }
        importQueue.addOperation {
            onMain {
                self.updatingFileLists = false
                if self.doingManagedRestore, !self.importTasks.isEmpty, self.totalRemainingTasks == 0 {
                    delay(3) { self.finishManagedRestore() }
                }
            }
        }
    }
    
    private func updateItemFiles() {
        print("updateItemFiles()")
        var files: [URL] = []
        for dir in findImportFolders(objectName: "TimelineItem") {
            files += findImportFiles(in: dir)
            // .sorted { $0.tidyiCloudFilename > $1.tidyiCloudFilename } // nope. uses too much memory and crashes the app
        }
        print("updateItemFiles() itemFiles: \(files.count)")
        onMain { self.itemFiles = files }
        updateDownloadingList(for: files)
    }
    
    private func updateSampleFiles() {
        print("updateSampleFiles()")
        var files: [URL] = []
        for dir in findImportFolders(objectName: "LocomotionSample") {
            files += findImportFiles(in: dir).sorted { $0.tidyiCloudFilename > $1.tidyiCloudFilename }
        }
        print("updateSampleFiles() sampleFiles: \(files.count)")
        onMain {
            self.sampleFiles = files
            if self.doingManagedRestore {
                self.updateQueuedSampleFiles()
            }
        }
        updateDownloadingList(for: files)
    }
    
    private func updatePlaceFiles() {
        print("updatePlaceFiles()")
        var files: [URL] = []
        for dir in findImportFolders(objectName: "Place") {
            files += findImportFiles(in: dir).sorted { $0.tidyiCloudFilename > $1.tidyiCloudFilename }
        }
        print("updatePlaceFiles() placeFiles: \(files.count)")
        onMain { self.placeFiles = files }
        updateDownloadingList(for: files)
    }
    
    private func updateNoteFiles() {
        print("updateNoteFiles()")
        var files: [URL] = []
        for dir in findImportFolders(objectName: "Note") {
            files += findImportFiles(in: dir).sorted { $0.tidyiCloudFilename > $1.tidyiCloudFilename }
        }
        print("updateNoteFiles() noteFiles: \(files.count)")
        onMain {
            self.noteFiles = files
            if self.doingManagedRestore {
                self.updateQueuedNoteFiles()
            }
        }
        updateDownloadingList(for: files)
    }
    
    private func updateSummaryFiles() {
        print("updateSummaryFiles()")
        var files: [URL] = []
        for dir in findImportFolders(objectName: "TimelineRangeSummary") {
            files += findImportFiles(in: dir).sorted { $0.tidyiCloudFilename > $1.tidyiCloudFilename }
        }
        print("updateSummaryFiles() summaryFiles: \(files.count)")
        onMain {
            self.summaryFiles = files
            if self.doingManagedRestore {
                self.updateQueuedSummaryFiles()
            }
        }
        updateDownloadingList(for: files)
    }
   
    private func updateDownloadingList(for files: [URL]) {
        if importTasks.isEmpty { return }
        for url in files where !url.lastPathComponent.hasSuffix("icloud") {
            for task in importTasks.values {
                var mutableTask = task
                
                if task.state == .downloading, task.filename == url.tidyiCloudFilename {
                    mutableTask.url = url
                    mutableTask.state = .created
                    updateImportTask(mutableTask)
                    print("Restarting import for: \(url.tidyiCloudFilename)")
                    importData(from: url) // throw it back into the import queue
                }
                
                if let match = task.downloadingDependents.first(where: { $0.tidyiCloudFilename == url.tidyiCloudFilename }) {
                    mutableTask.downloadingDependents.remove(match)
                    updateImportTask(mutableTask)
                    print("Finished downloading: \(url.tidyiCloudFilename)")
                    if mutableTask.downloadingDependents.isEmpty, !mutableTask.state.isActive {
                        print("Restarting import for: \(url.tidyiCloudFilename)")
                        importData(from: url) // throw it back into the import queue
                    }
                }
            }
        }
    }
    
    // MARK: -

    private func findImportFolders(objectName: String) -> [URL] {
        guard let importDir = importDir else { return [] }
        guard let enumerator = manager.enumerator(at: importDir, includingPropertiesForKeys: []) else { return [] }
        
        let start = importDir.absoluteString.endIndex
        
        var matches: [URL] = []
        while let url = enumerator.nextObject() as? URL {
            if !url.hasDirectoryPath { continue }
            
            let relative = url.absoluteString.suffix(from: start)

            if let last = url.absoluteString.suffix(from: start).split(separator: "/").last, last == objectName {
                matches.append(url)
                print("objectName: \(objectName), match: \(relative)")
            }
        }
        
        return matches
    }
    
    private func findImportFiles(in dir: URL) -> [URL] {
        guard let enumerator = manager.enumerator(at: dir, includingPropertiesForKeys: []) else { return [] }
        
        var files: [URL] = []
        while let url = enumerator.nextObject() as? URL {
            if url.hasDirectoryPath { continue }
            let last = url.lastPathComponent
            if last.hasSuffix("json") || last.hasSuffix("json.icloud") || last.hasSuffix("json.gz") || last.hasSuffix("json.gz.icloud") {
                files.append(url)
            }
        }

        return files
    }
    
    // MARK: - File observing
    
    public func startWatchingFiles() {
        onMain { [self] in
            if watchFilesQuery?.isStarted == true { return }
            print("startWatchingFiles()")
            watchFilesQuery?.start()
        }
    }
    
    public func stopWatchingFiles() {
        if watchFilesQuery?.isStarted == true {
            print("stopWatchingFiles()")
        }
        watchFilesQuery?.stop()
    }
    
    private lazy var watchFilesQuery: NSMetadataQuery? = {
        let query = NSMetadataQuery()
        query.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
        query.predicate = NSPredicate(format: "%K LIKE '*'", NSMetadataItemFSNameKey)
        return query
    }()
    
    // MARK: - Misc

    var importDir: URL? {
        return FileManager.default.iCloudDocsDir?.appendingPathComponent("Import", isDirectory: true)
    }
    
    let importQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "ArcApp.importQueue"
        queue.qualityOfService = .utility
        queue.maxConcurrentOperationCount = 2
        return queue
    }()

}
