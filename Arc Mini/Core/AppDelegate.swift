//
//  AppDelegate.swift
//  Arc Mini
//
//  Created by Matt Greenfield on 2/3/20.
//  Copyright © 2020 Matt Greenfield. All rights reserved.
//

import UIKit
import Sentry
import LocoKit
import SwiftNotes

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    static var thermalState: ProcessInfo.ThermalState = .nominal

    static var highlander: AppDelegate {
        return UIApplication.shared.delegate as! AppDelegate
    }

    // MARK: - App lifecycle

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        if let sentryDSN = Settings.sentryDSN {
            SentrySDK.start { options in
                options.dsn = sentryDSN
                options.enableAutoSessionTracking = true
                options.sessionTrackingIntervalMillis = UInt(TimeInterval.oneHour * 6 * 1000)
                options.debug = true // Enabled debug when first installing is always helpful
            }
            if let userId = UIDevice.current.identifierForVendor {
                SentrySDK.setUser(Sentry.User(userId: userId.uuidString))
            }
        }

        logger.info("didFinishLaunchingWithOptions")

        LocoKitService.apiKey = "bee1aa1af978486b9186780a07cc240e"
        ActivityTypesCache.highlander.store = RecordingManager.store
        LocomotionManager.highlander.coordinateAssessor = CoordinateTrustManager(store: RecordingManager.store)
        LocomotionManager.highlander.appGroup = AppGroup(appName: .arcMini, suiteName: "group.ArcApp")

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

        // onboarding (barely. heh)
        LocomotionManager.highlander.requestLocationPermission(background: true)
        LocomotionManager.highlander.startCoreMotion()

        delay(6) { RecordingManager.highlander.startRecording() }
        
        return true
    }

    func applicationWillTerminate(_ application: UIApplication) {
        logger.info("applicationWillTerminate")
    }

    // MARK: -

    func applyUIAppearanceOverrides() {
        UITableView.appearance().separatorStyle = .none
        UITableView.appearance().showsVerticalScrollIndicator = false // TODO: want this per view, not global
    }

    func thermalStateChanged() {
        AppDelegate.thermalState = ProcessInfo.processInfo.thermalState
        logger.info("thermalState: \(AppDelegate.thermalState.stringValue)")
    }

    // MARK: - Memory footprint

    private static let memoryFormatter: MeasurementFormatter = {
        let formatter = MeasurementFormatter()
        formatter.unitStyle = .medium
        formatter.unitOptions = .providedUnit
        formatter.numberFormatter.maximumFractionDigits = 0
        return formatter
    }()

    static var memoryString: String? {
        guard let footprint = ProcessInfo.processInfo.memoryFootprint else { return nil }
        return memoryFormatter.string(from: footprint.converted(to: .megabytes))
    }

}

