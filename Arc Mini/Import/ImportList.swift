//
//  ImportList.swift
//  Arc
//
//  Created by Matt Greenfield on 15/1/21.
//  Copyright © 2021 Big Paua. All rights reserved.
//

import SwiftUI

struct ImportList: View {
    
    @ObservedObject var importer: ArcImporter
    var dismissAction: (() -> Void)

    @State var showingInfoSheet = false
    @State var taskForInfoSheet: ImportTask?
    @State var showingSamples = true
    @State var showingNotes = true
    @State var showingSummaries = true
    @State var showingItems = true
    @State var showingPlaces = true
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Spacer()
                Text("IMPORT").font(.custom("Silka-Black", size: 14)).kerning(2).foregroundColor(.black)
                Spacer().overlay(closeButton)
            }.frame(height: 64)
            Rectangle().fill(Color(0xE2E2E2)).frame(height: .onePixel)
            
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    Group {
                        Spacer().frame(height: 20)
                        HStack {
                            Image(systemName: showingSamples ? "arrowtriangle.down.fill" : "arrowtriangle.forward.fill")
                                .foregroundColor(Color.black)
                                .onTapGesture { showingSamples.toggle() }
                            Text("\(importer.sampleFiles.count) Sample Files")
                                .font(.custom("Silka-SemiBold", size: 16))
                                .foregroundColor(Color.black)
                                .frame(height: 60)
                            Spacer()
                            if showingSamples, !importer.sampleFiles.isEmpty {
                                Button {
                                    tappedImportAllSamples()
                                } label: {
                                    Text("Import All")
                                        .font(.custom("Silka-SemiBold", size: 16))
                                        .foregroundColor(Color(0x7A3CFC))
                                        .frame(height: 60)
                                }
                            }
                        }
                        Rectangle().fill(Color(0xE2E2E2)).frame(height: .onePixel)
                        
                        if showingSamples {
                            ForEach(importer.sampleFiles, id: \.absoluteString) { url in
                                Button {
                                    tappedSamples(url: url)
                                } label: {
                                    row(for: url)
                                }
                                Rectangle().fill(Color(0xE2E2E2)).frame(height: .onePixel)
                            }
                        }
                    }
                    
                    Group {
                        Spacer().frame(height: 20)
                        HStack {
                            Image(systemName: showingNotes ? "arrowtriangle.down.fill" : "arrowtriangle.forward.fill")
                                .foregroundColor(Color.black)
                                .onTapGesture { showingNotes.toggle() }
                            Text("\(importer.noteFiles.count) Note Files")
                                .font(.custom("Silka-SemiBold", size: 16))
                                .foregroundColor(Color.black)
                                .frame(height: 60)
                            Spacer()
                            if showingNotes, !importer.noteFiles.isEmpty {
                                Button {
                                    tappedImportAllNotes()
                                } label: {
                                    Text("Import All")
                                        .font(.custom("Silka-SemiBold", size: 16))
                                        .foregroundColor(Color(0x7A3CFC))
                                        .frame(height: 60)
                                }
                            }
                        }
                        Rectangle().fill(Color(0xE2E2E2)).frame(height: .onePixel)
                        
                        if showingNotes {
                            ForEach(importer.noteFiles, id: \.absoluteString) { url in
                                Button {
                                    tappedNote(url: url)
                                } label: {
                                    row(for: url)
                                }
                                Rectangle().fill(Color(0xE2E2E2)).frame(height: .onePixel)
                            }
                        }
                    }
                    
                    Group {
                        Spacer().frame(height: 20)
                        HStack {
                            Image(systemName: showingSummaries ? "arrowtriangle.down.fill" : "arrowtriangle.forward.fill")
                                .foregroundColor(Color.black)
                                .onTapGesture { showingSummaries.toggle() }
                            Text("\(importer.summaryFiles.count) Day Summary Files")
                                .font(.custom("Silka-SemiBold", size: 16))
                                .foregroundColor(Color.black)
                                .frame(height: 60)
                            Spacer()
                            if showingSummaries, !importer.summaryFiles.isEmpty {
                                Button {
                                    tappedImportAllSummaries()
                                } label: {
                                    Text("Import All")
                                        .font(.custom("Silka-SemiBold", size: 16))
                                        .foregroundColor(Color(0x7A3CFC))
                                        .frame(height: 60)
                                }
                            }
                        }
                        Rectangle().fill(Color(0xE2E2E2)).frame(height: .onePixel)
                        
                        if showingSummaries {
                            ForEach(importer.summaryFiles, id: \.absoluteString) { url in
                                Button {
                                    tappedSummary(url: url)
                                } label: {
                                    row(for: url)
                                }
                                Rectangle().fill(Color(0xE2E2E2)).frame(height: .onePixel)
                            }
                        }
                    }
                    
                    Group {
                        Spacer().frame(height: 20)
                        HStack {
                            Image(systemName: showingItems ? "arrowtriangle.down.fill" : "arrowtriangle.forward.fill")
                                .foregroundColor(Color.black)
                                .onTapGesture { showingItems.toggle() }
                            Text("\(importer.itemFiles.count) Timeline Item Files")
                                .font(.custom("Silka-SemiBold", size: 16))
                                .foregroundColor(Color.black)
                                .frame(height: 60)
                        }
                        Rectangle().fill(Color(0xE2E2E2)).frame(height: .onePixel)
                        
                        if showingItems {
                            ForEach(importer.itemFiles, id: \.absoluteString) { url in
                                Button {
                                    tappedItem(url: url)
                                } label: {
                                    row(for: url)
                                }
                                Rectangle().fill(Color(0xE2E2E2)).frame(height: .onePixel)
                            }
                        }
                    }
                    
                    Group {
                        Spacer().frame(height: 20)
                        HStack {
                            Image(systemName: showingPlaces ? "arrowtriangle.down.fill" : "arrowtriangle.forward.fill")
                                .foregroundColor(Color.black)
                                .onTapGesture { showingPlaces.toggle() }
                            Text("\(importer.placeFiles.count) Place Files")
                                .font(.custom("Silka-SemiBold", size: 16))
                                .foregroundColor(Color.black)
                                .frame(height: 60)
                        }
                        Rectangle().fill(Color(0xE2E2E2)).frame(height: .onePixel)
                        
                        if showingPlaces {
                            ForEach(importer.placeFiles, id: \.absoluteString) { url in
                                Button {
                                    tappedPlace(url: url)
                                } label: {
                                    row(for: url)
                                }
                                Rectangle().fill(Color(0xE2E2E2)).frame(height: .onePixel)
                            }
                        }
                    }
                }
                .padding([.leading, .trailing], 20)
            }
        }
        .background(Color.white.ignoresSafeArea())
        .onAppear { importer.startWatchingFiles() }
        .onDisappear { importer.stopWatchingFiles() }
        .sheet(isPresented: $showingInfoSheet, onDismiss: { taskForInfoSheet = nil }) {
            if let task = taskForInfoSheet {
                ImportTaskDetails(task: task)
            }
        }
    }
    
    func row(for url: URL) -> some View {
        return HStack {
            Text(url.tidyiCloudFilename)
                .font(.custom("Menlo", size: 11))
                .foregroundColor(Color.black)
            
            Spacer()
            
            if let task = importer.importTask(for: url) {
                switch task.state {
                case .created:
                    if url.lastPathComponent.hasSuffix("icloud") {
                        Image(systemName: "icloud").foregroundColor(Color(0x999999))
                    }
                case .queued:
                    Image(systemName: "clock").foregroundColor(Color(0x999999))
                case .downloading:
                    Image(systemName: "icloud.and.arrow.down").foregroundColor(Color(0x999999))
                case .opening:
                    Image(systemName: "doc.zipper").foregroundColor(Color(0x999999))
                case .importing:
                    ProgressView(value: task.progress).frame(width: 44)
                case .waiting:
                    Image(systemName: "exclamationmark.arrow.circlepath").foregroundColor(Color(0x999999))
                case .finished:
                    Image(systemName: "checkmark").foregroundColor(Color(0x999999))
                case .errored:
                    Button {
                        delay(0.01) { self.taskForInfoSheet = task }
                        self.showingInfoSheet = true
                    } label: {
                        Image(systemName: "exclamationmark.circle").foregroundColor(Color.red)
                    }
                }
                
            } else if url.lastPathComponent.hasSuffix("icloud") {
                Image(systemName: "icloud").foregroundColor(Color(0x999999))
            }
        }
        .frame(height: 44)
    }
    
    // MARK: -
    
    var closeButton: some View {
        Button {
            dismissAction()
        } label: {
            HStack {
                Spacer()
                Image("closeIcon24")
                    .foregroundColor(Color(0x7A3CFC))
                    .padding(.trailing, 20)
            }
        }
        .frame(height: 64)
    }

    // MARK: -
    
    func tappedSamples(url: URL) {
        if importer.importTask(for: url)?.state.isActive != true {
            importer.importSamples(from: url)
        }
    }
    
    func tappedNote(url: URL) {
        importer.importNote(from: url)
    }
    
    func tappedSummary(url: URL) {
        importer.importSummary(from: url)
    }
    
    func tappedItem(url: URL) {
        do {
            try importer.importItem(from: url)
        } catch {
            logger.error(error, subsystem: .backups)
        }
    }
    
    func tappedPlace(url: URL) {
        do {
            try importer.importPlace(from: url)
        } catch {
            logger.error(error, subsystem: .backups)
        }
    }
    
    func tappedImportAllSamples() {
        for url in importer.sampleFiles {
            if importer.importTask(for: url)?.state.isActive != true {
                importer.importSamples(from: url)
            }
        }
    }
    
    func tappedImportAllNotes() {
        for url in importer.noteFiles {
            if importer.importTask(for: url)?.state.isActive != true {
                importer.importNote(from: url)
            }
        }
    }
    
    func tappedImportAllSummaries() {
        for url in importer.summaryFiles {
            if importer.importTask(for: url)?.state.isActive != true {
                importer.importSummary(from: url)
            }
        }
    }
    
}
