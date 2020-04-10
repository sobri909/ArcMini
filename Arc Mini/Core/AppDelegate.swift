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

    static var highlander: AppDelegate {
        return UIApplication.shared.delegate as! AppDelegate
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        logger.info("APP LAUNCHED")

        LocoKitService.apiKey = "bee1aa1af978486b9186780a07cc240e"
        ActivityTypesCache.highlander.store = RecordingManager.store
        LocomotionManager.highlander.requestLocationPermission(background: true)
        LocomotionManager.highlander.coordinateAssessor = CoordinateTrustManager(store: RecordingManager.store)
        RecordingManager.recorder.startRecording()

        UIDevice.current.isBatteryMonitoringEnabled = true

        registerBackgroundTasks()

        if UIDevice.current.batteryState != .unplugged {
            scheduleBackgroundTasks()
        }

        when(UIDevice.batteryStateDidChangeNotification) { _ in
            if UIDevice.current.batteryState != .unplugged {
                self.scheduleBackgroundTasks()
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
        scheduler.register(forTaskWithIdentifier: "com.bigpaua.ArcMini.placeModelUpdates", using: nil) { task in
            logger.info("UPDATE QUEUED PLACES: START")
            PlaceCache.cache.updateQueuedPlaces(task: task as! BGProcessingTask)
        }
        scheduler.register(
            forTaskWithIdentifier: "com.bigpaua.ArcMini.updateTrustFactors",
            using: Jobs.highlander.secondaryQueue.underlyingQueue)
        { task in
            logger.info("UPDATE TRUST FACTORS: START")
            (LocomotionManager.highlander.coordinateAssessor as? CoordinateTrustManager)?.updateTrustFactors()
            logger.info("UPDATE TRUST FACTORS: COMPLETED")
            task.setTaskCompleted(success: true)
        }
    }

    func scheduleBackgroundTasks() {
        if LocomotionManager.highlander.recordingState == .recording { return }
        scheduleBackgroundTask("com.bigpaua.ArcMini.placeModelUpdates", requiresPower: true)
        scheduleBackgroundTask("com.bigpaua.ArcMini.updateTrustFactors", requiresPower: true)
    }

    func scheduleBackgroundTask(_ identifier: String, requiresPower: Bool, requiresNetwork: Bool = false) {
        let request = BGProcessingTaskRequest(identifier: identifier)
        request.requiresNetworkConnectivity = requiresNetwork
        request.requiresExternalPower = requiresPower
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            logger.error("FAILED REQUEST: \(identifier)")
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

