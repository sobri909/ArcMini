//
//  AppDelegate.swift
//  Arc Mini
//
//  Created by Matt Greenfield on 2/3/20.
//  Copyright © 2020 Matt Greenfield. All rights reserved.
//

import UIKit
import LocoKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    static let store = ArcStore()
    static let recorder = TimelineRecorder(store: store, classifier: TimelineClassifier.highlander)

    private static var _todaySegment: TimelineSegment?
    static var todaySegment: TimelineSegment {
        // flush outdated
        if let dateRange = _todaySegment?.dateRange, !dateRange.containsNow { _todaySegment = nil }

        // create if missing
        if _todaySegment == nil {
            _todaySegment = AppDelegate.store.segment(for: Calendar.current.dateInterval(of: .day, for: Date())!)
        }

        return _todaySegment!
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        LocoKitService.apiKey = "bee1aa1af978486b9186780a07cc240e"
        ActivityTypesCache.highlander.store = AppDelegate.store

        LocomotionManager.highlander.requestLocationPermission(background: true)
        
        AppDelegate.recorder.startRecording()

        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }


}

