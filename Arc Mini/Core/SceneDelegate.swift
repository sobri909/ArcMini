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

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?
    var scene: UIScene?

    var mapState = MapState()
    var timelineState = TimelineState()

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        self.scene = scene
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        logger.info("sceneDidDisconnect")
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        growAFullHead()
    }

    func sceneWillResignActive(_ scene: UIScene) {}

    func sceneWillEnterForeground(_ scene: UIScene) {}

    func sceneDidEnterBackground(_ scene: UIScene) {
        if LocomotionManager.highlander.recordingState == .standby {
            goFullyHeadless()
        }
    }

    // MARK: -

    func growAFullHead() {
        onMain {
            guard self.window == nil else { return }
            guard let scene = self.scene as? UIWindowScene else { return }
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
            self.window?.rootViewController?.view.removeFromSuperview()
            self.window?.rootViewController = nil
            self.window = nil
            self.mapState.flush()
            logger.info("WENT FULLY HEADLESS")
        }
    }

}

