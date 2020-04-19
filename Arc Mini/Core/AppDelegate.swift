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

    static var thermalState: ProcessInfo.ThermalState = .nominal

    static var highlander: AppDelegate {
        return UIApplication.shared.delegate as! AppDelegate
    }

    // MARK: - App lifecycle

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        logger.info("didFinishLaunchingWithOptions")

        LocoKitService.apiKey = "bee1aa1af978486b9186780a07cc240e"
        ActivityTypesCache.highlander.store = RecordingManager.store
        LocomotionManager.highlander.requestLocationPermission(background: true)
        LocomotionManager.highlander.coordinateAssessor = CoordinateTrustManager(store: RecordingManager.store)
        RecordingManager.recorder.startRecording()

        UIDevice.current.isBatteryMonitoringEnabled = true

        thermalStateChanged()
        TasksManager.highlander.registerBackgroundTasks()

        when(UIDevice.batteryStateDidChangeNotification) { _ in
            if UIDevice.current.batteryState != .unplugged {
                TasksManager.highlander.scheduleBackgroundTasks()
            }
        }

        when(ProcessInfo.thermalStateDidChangeNotification) { _ in
            self.thermalStateChanged()
        }

        applyUIAppearanceOverrides()
        
        return true
    }

    func applicationWillTerminate(_ application: UIApplication) {
        logger.info("applicationWillTerminate")
    }

    // MARK: -

    func applyUIAppearanceOverrides() {
        UITableView.appearance().separatorStyle = .none
        UITableView.appearance().showsVerticalScrollIndicator = false // TODO: want this per view, not global
        UITableViewCell.appearance().selectionStyle = .none // TODO: want this per view, not global
    }

    func thermalStateChanged() {
        AppDelegate.thermalState = ProcessInfo.processInfo.thermalState
        logger.info("thermalState: \(AppDelegate.thermalState.stringValue)")
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

