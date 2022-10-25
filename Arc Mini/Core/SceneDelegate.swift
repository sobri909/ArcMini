//
//  SceneDelegate.swift
//  Arc Mini
//
//  Created by Matt Greenfield on 2/3/20.
//  Copyright © 2020 Matt Greenfield. All rights reserved.
//

import UIKit
import SwiftUI
import LocoKit
import WidgetKit
import SwiftNotes

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?
    var scene: UIScene?
    var backgroundingDate: Date?
    var timeInBackground: TimeInterval { return backgroundingDate?.age ?? 0 }

    let goHeadlessAfterBackgroundTime: TimeInterval = .oneMinute * 8

    override init() {
        super.init()

        when(.tookOverRecording) { _ in
            logger.info("tookOverRecording", subsystem: .locokit)
            WidgetCenter.shared.reloadAllTimelines()
        }

        when(.concededRecording) { _ in
            if let currentRecorder = LocomotionManager.highlander.appGroup?.currentRecorder {
                logger.info("concededRecording to \(currentRecorder.appName)", subsystem: .locokit)
            } else {
                logger.info("concededRecording to UNKNOWN!", subsystem: .locokit)
            }
            WidgetCenter.shared.reloadAllTimelines()
            self.goFullyHeadless()
        }
        
        when(.currentItemChanged) { _ in
            logger.info("currentItemChanged", subsystem: .locokit)
            WidgetCenter.shared.reloadAllTimelines()
        }

        when(.currentItemTitleChanged) { _ in
            logger.info("currentItemTitleChanged", subsystem: .locokit)
            WidgetCenter.shared.reloadAllTimelines()
        }
        
        when(.timelineObjectsExternallyModified) { _ in
            RecordingManager.store.connectToDatabase()
            guard let appGroup = LocomotionManager.highlander.appGroup else { return }
            guard let currentItem = RecordingManager.recorder.currentItem else { return }
            if appGroup.currentRecorder?.currentItemTitle != currentItem.title {
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
    }

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        self.scene = scene
    }

    func sceneDidBecomeActive(_ scene: UIScene) {

        // take over recording in foreground
        let loco = LocomotionManager.highlander
        if let appGroup = loco.appGroup, !appGroup.isAnActiveRecorder {
            RecordingManager.store.connectToDatabase()
            loco.becomeTheActiveRecorder()
        }

        growAFullHead()
    }
    
    func sceneDidEnterBackground(_ scene: UIScene) {
        backgroundingDate = Date()
        
        // go headless after long enough in background
        delay(goHeadlessAfterBackgroundTime + 1) {
            if self.timeInBackground >= self.goHeadlessAfterBackgroundTime {
                self.goFullyHeadless()
            }
        }
    }

    // MARK: -

    func growAFullHead() {
        onMain {
            guard self.window == nil else { return }
            guard let scene = self.scene as? UIWindowScene else { return }

            RecordingManager.store.connectToDatabase()
            
            let window = UIWindow(windowScene: scene)
            let rootView = RootView()
                .environmentObject(TimelineState.highlander)
                .environmentObject(MapState.highlander)
            window.rootViewController = UIHostingController(rootView: rootView)
            self.window = window
            window.makeKeyAndVisible()

            logger.info("Grew a full head", subsystem: .ui)
        }
    }

    func goFullyHeadless() {
        onMain {
            guard self.window != nil else { return }
            guard LocomotionManager.highlander.applicationState != .active else { return }

            self.window?.rootViewController?.view.removeFromSuperview()
            self.window?.rootViewController = nil
            self.window = nil
            MapState.highlander.flush()

            logger.info("Went fully headless", subsystem: .ui)

            delay(6) { RecordingManager.safelyDisconnectFromDatabase() }
        }
    }

}

