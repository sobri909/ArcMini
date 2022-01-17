//
//  RestoreView.swift
//  Arc
//
//  Created by Matt Greenfield on 17/4/21.
//  Copyright © 2021 Big Paua. All rights reserved.
//

import SwiftUI

struct RestoreView: View {
    
    @ObservedObject var importer: ArcImporter
    @State var showingLogView = false
    var dismissAction: (() -> Void)

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Spacer()
                Text("RESTORE").font(.custom("Silka-Black", size: 14)).kerning(2).foregroundColor(.black)
                Spacer().overlay(closeButton)
            }.frame(height: 64)
            Rectangle().fill(Color(0xE2E2E2)).frame(height: .onePixel)
            
            ScrollView {
                VStack(spacing: 0) {
                    Spacer().frame(height: 40)
                    
                    if shitsHappening {
                        if importer.collatingFilesToDownload || importer.restoreDownloading > 0 {
                            downloadingFilesCopy
                        } else {
                            doingRestoreCopy
                        }
                    } else if importer.restoreDirExists {
                        haveRestoreFolderCopy
                    } else if importer.finishedManageRestore {
                        finishedRestoreCopy
                    } else {
                        foundFolderCopy
                    }

                    Spacer().frame(height: 36)
                    
                    if shitsHappening {
                        Rectangle().fill(Color(0xE2E2E2)).frame(height: .onePixel)

                    } else {
                        Button {
                            ArcImporter.startManagedRestore()
                        } label: {
                            HStack {
                                Spacer()
                                Text(shitsHappening ? "Restoring" : "Restore now")
                                    .font(.custom("Silka-SemiBold", size: 16))
                                    .foregroundColor(Color.white)
                                Spacer()
                            }
                            .frame(height: 48)
                            .background(Color(0x12A656))
                            .cornerRadius(8)
                            .opacity(shitsHappening ? 0.5 : 1)
                            .disabled(shitsHappening)
                        }
                    }
                    
                    if !importer.doingManagedRestore, !importer.restoreDirExists, !importer.finishedManageRestore {
                        Spacer().frame(height: 6)
                        Button {
                            Settings.highlander[.possibleRestoreDir] = nil
                            AppDelegate.timelineController?.hideInfoBar()
                            dismissAction()
                            
                        } label: {
                            Text("Ignore the folder and don't restore")
                                .font(.custom("Silka-Medium", size: 15))
                                .frame(height: 44)
                        }
                    }

                    if importer.doingManagedRestore {
                        Spacer().frame(height: 40)

                        Text("Progress")
                            .font(.custom("Silka-Bold", size: 22)).kerning(0.33)
                            .foregroundColor(Color.black)
                        
                        Spacer().frame(height: 15)
                        
                        if importer.restoreDownloading > 0 {
                            row(Text("Downloading from iCloud"), Text("\(importer.restoreDownloading)"))
                            
                        } else if importer.collatingFilesToDownload || importer.copyingRestoreFolder || importer.updatingFileLists {
                            Text("Identifying backup files...")
                                .font(.custom("Silka-Medium", size: 15))
                                .foregroundColor(Color(0x6F7072))

                        } else {
                            if importer.totalSampleWeekTasks > 0 {
                                row(Text("Timeline weeks restored"), Text("\(importer.finishedSampleWeekTasks) of \(importer.totalSampleWeekTasks)"))
                            }
                            if importer.totalSummaryTasks > 0 {
                                row(Text("Timeline summaries restored"), Text("\(importer.finishedSummaryTasks) of \(importer.totalSummaryTasks)"))
                            }
                            if importer.totalNoteTasks > 0 {
                                row(Text("Notes restored"), Text("\(importer.finishedNoteTasks) of \(importer.totalNoteTasks)"))
                            }
                        }
                        
                        if importer.tasksDownloading > 0 {
                            row(Text("Downloading from iCloud"), Text("\(importer.tasksDownloading)"))
                        }
                        if importer.totalErrors > 0 {
                            row(Text("Errors"), Text("\(importer.totalErrors)"))
                            Button {
                                showingLogView = true
                            } label: {
                                Text("View errors log")
                                    .font(.custom("Silka-Medium", size: 15))
                            }
                            .frame(height: 44)
                        }
                    }
                }
                .padding(0)
                .transition(.opacity)
                .animation(.default)
            }
            .padding([.leading, .trailing], 20)
        }
        .background(Color.white.ignoresSafeArea())
        .sheet(isPresented: $showingLogView) {
            ErrorLogView()
        }
    }
    
    // MARK: - Copy
    
    var foundFolderCopy: some View {
        return VStack {
            Text("Found backup folder")
                .font(.custom("Silka-Bold", size: 22)).kerning(0.33)
                .foregroundColor(Color.black)
            
            Spacer().frame(height: 15)
            
            Text("A backup folder has been found in Arc's iCloud Drive folder that can be used to restore your data.")
                .font(.custom("Silka-Medium", size: 15)).lineSpacing(5).multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundColor(Color(0x6F7072))
        }
    }

    var haveRestoreFolderCopy: some View {
        return VStack {
            Text("Found restore folder")
                .font(.custom("Silka-Bold", size: 22)).kerning(0.33)
                .foregroundColor(Color.black)
            
            Spacer().frame(height: 15)
            
            Text("A restore folder has been found in Arc's Import folder that can be used to restore your data.")
                .font(.custom("Silka-Medium", size: 15)).lineSpacing(5).multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundColor(Color(0x6F7072))
        }
    }
    
    var downloadingFilesCopy: some View {
        return VStack {
            Text("Downloading")
                .font(.custom("Silka-Bold", size: 22)).kerning(0.33)
                .foregroundColor(Color.black)
            
            Spacer().frame(height: 15)
            
            Text("Some of the files in the backup folder are not yet on your phone, and are being queued for download from iCloud.\n\n"
                    + "Syncing files from iCloud can take some time, depending on the number of files and iCloud's mood.\n\n"
                    + "It's okay to close this view and use the app as normal while the downloading and restore continues.")
                .font(.custom("Silka-Medium", size: 15)).lineSpacing(5).multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundColor(Color(0x6F7072))
        }
    }
    
    var doingRestoreCopy: some View {
        return VStack {
            Text("Restoring")
                .font(.custom("Silka-Bold", size: 22)).kerning(0.33)
                .foregroundColor(Color.black)
            
            Spacer().frame(height: 15)
            
            Text("A full restore may take an hour or more to complete.\n\n"
                    + "It's okay to close this view and use the app as normal while the restore continues.")
                .font(.custom("Silka-Medium", size: 15)).lineSpacing(5).multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundColor(Color(0x6F7072))
        }
    }
    
    var finishedRestoreCopy: some View {
        return VStack {
            Text("Finished!")
                .font(.custom("Silka-Bold", size: 22)).kerning(0.33)
                .foregroundColor(Color.black)
            
            Spacer().frame(height: 15)
            
            Text("The restore of your backup files has completed.")
                .font(.custom("Silka-Medium", size: 15)).lineSpacing(5).multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundColor(Color(0x6F7072))
        }
    }
    
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
    
    func row(_ leftText: Text, _ rightText: Text? = nil) -> some View {
        return HStack {
            leftText
                .font(.custom("Silka-Medium", size: 15))
                .foregroundColor(Color(0x6F7072))
            Spacer()
            if let rightText = rightText {
                rightText
                    .font(.custom("Silka-Medium", size: 15))
                    .foregroundColor(Color(0x6F7072))
            }
        }
        .frame(height: 44)
    }
    
    // MARK: - Misc getters
    
    var shitsHappening: Bool {
        if !importer.downloadingOriginRestoreFiles.isEmpty { return true }
        if importer.copyingRestoreFolder { return true }
        if importer.doingManagedRestore { return true }
        if importer.haveActiveTasks { return true }
        return false
    }

}
