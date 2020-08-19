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

    var mapState = MapState()
    var timelineState = TimelineState()

    override init() {
        super.init()

        when(.tookOverRecording) { _ in
            logger.info("tookOverRecording")
            WidgetCenter.shared.reloadAllTimelines()
        }

        when(.concededRecording) { _ in
            if let currentRecorder = LocomotionManager.highlander.appGroup?.currentRecorder {
                logger.info("concededRecording to \(currentRecorder.appName)")
            } else {
                logger.info("concededRecording to UNKNOWN!")
            }
            WidgetCenter.shared.reloadAllTimelines()
            self.goFullyHeadless()
            RecordingManager.store.disconnectFromDatabase()
        }
    }

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        self.scene = scene
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        Jobs.highlander.didBecomeActive()

        // take over recording in foreground
        let loco = LocomotionManager.highlander
        if let appGroup = loco.appGroup, !appGroup.isAnActiveRecorder {
            RecordingManager.store.connectToDatabase()
            loco.becomeTheActiveRecorder()
        }

        growAFullHead()
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        Jobs.highlander.didEnterBackground()
    }

    // MARK: -

    func growAFullHead() {
        onMain {
            guard self.window == nil else { return }
            guard let scene = self.scene as? UIWindowScene else { return }

            RecordingManager.store.connectToDatabase()
            
            let window = UIWindow(windowScene: scene)
            let rootView = RootView()
                .environmentObject(self.timelineState)
                .environmentObject(self.mapState)
            window.rootViewController = UIHostingController(rootView: rootView)
            self.window = window
            window.makeKeyAndVisible()

            logger.info("GREW A FULL HEAD")
        }
    }

    func goFullyHeadless() {
        onMain {
            guard self.window != nil else { return }
            guard LocomotionManager.highlander.applicationState != .active else { return }

            self.window?.rootViewController?.view.removeFromSuperview()
            self.window?.rootViewController = nil
            self.window = nil
            self.mapState.flush()

            logger.info("WENT FULLY HEADLESS")
        }
    }

}

