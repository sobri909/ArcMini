//
//  AppDelegate.swift
//  Arc Mini
//
//  Created by Matt Greenfield on 2/3/20.
//  Copyright © 2020 Matt Greenfield. All rights reserved.
//

import UIKit
import LocoKit
import SwiftNotes
import BackgroundTasks

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        LocoKitService.apiKey = "bee1aa1af978486b9186780a07cc240e"
        ActivityTypesCache.highlander.store = RecordingManager.store
        LocomotionManager.highlander.requestLocationPermission(background: true)
        LocomotionManager.highlander.coordinateAssessor = CoordinateTrustManager(store: RecordingManager.store)
        RecordingManager.recorder.startRecording()

        UIDevice.current.isBatteryMonitoringEnabled = true

        if UIDevice.current.batteryState == .charging || UIDevice.current.batteryState == .full {
            registerBackgroundTasks()
        }

        when(UIDevice.batteryStateDidChangeNotification) { _ in
            if UIDevice.current.batteryState == .charging {
                print("batteryStateDidChange: CHARGING")
                self.registerBackgroundTasks()
            }
        }

        applyUIAppearanceOverrides()
        
        return true
    }

    func applyUIAppearanceOverrides() {
        UITableView.appearance().separatorStyle = .none
        UITableView.appearance().showsVerticalScrollIndicator = false
        UITableViewCell.appearance().selectionStyle = .none
    }

    func registerBackgroundTasks() {
        let scheduler = BGTaskScheduler.shared
        scheduler.register(forTaskWithIdentifier: "com.bigpaua.ArcMini.updateTrustFactors",
                           using: Jobs.highlander.secondaryQueue.underlyingQueue) { task in
            print("UPDATE TRUST FACTORS: START")
            (LocomotionManager.highlander.coordinateAssessor as? CoordinateTrustManager)?.updateTrustFactors()
            print("UPDATE TRUST FACTORS: COMPLETED")
            task.setTaskCompleted(success: true)
        }
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

