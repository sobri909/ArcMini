//
//  Settings.swift
//  LearnerCoacher
//
//  Created by Matt Greenfield on 9/08/16.
//  Copyright © 2016 Big Paua. All rights reserved.
//

import LocoKit
import HealthKit
import UserNotifications

enum SettingsKey: String {
    case buildNumber

    // sessions
    case recordingOn
    case sharingOn
    case totalBackgroundTime
    case totalForegroundTime
    case backgroundFailDate
    case lastTerminatedDate

    // onboarding
    case haveRequestedHealthPermissions
    case haveRequestedMotionPermissions

    case foursquareToken
    case lastFmUsername
    case lastSwarmCheckinDate
    case lastLastFmTrackDate

    case showEndTimesOnTimeline

    case allowMapRotate
    case allowMapTilt
}

// MARK: -

class Settings {

    static let highlander = Settings()

    // MARK: -

    static let earliestAllowedDate = Date(timeIntervalSince1970: 946684800) // 01-1-2000 (earlier than Arc App, to allow Moves imports)

    // MARK: -

    static var recordingOn: Bool { return highlander[.recordingOn] as? Bool ?? true }
    static var sharingOn: Bool { return highlander[.sharingOn] as? Bool ?? true }

    static var showEndTimesOnTimeline: Bool {
        get { return highlander[.showEndTimesOnTimeline] as? Bool ?? false }
        set(newValue) { highlander[.showEndTimesOnTimeline] = newValue }
    }

    static var allowMapRotate: Bool {
        get { return highlander[.allowMapRotate] as? Bool ?? false }
        set(newValue) { highlander[.allowMapRotate] = newValue }
    }

    static var allowMapTilt: Bool {
        get { return highlander[.allowMapTilt] as? Bool ?? false }
        set(newValue) { highlander[.allowMapTilt] = newValue }
    }

    // MARK: -

    static var totalBackgroundTime: TimeInterval {
        get { return highlander[.totalBackgroundTime] as? TimeInterval ?? 0 }
        set(newValue) { highlander[.totalBackgroundTime] = newValue }
    }
    static var totalForegroundTime: TimeInterval {
        get { return highlander[.totalForegroundTime] as? TimeInterval ?? 0 }
        set(newValue) { highlander[.totalForegroundTime] = newValue }
    }
//    static var totalUptime: TimeInterval {
//        let total = totalBackgroundTime + totalForegroundTime
//        return total > 0 ? total : AppDelegate.delly.uptime
//    }
//    static var foregroundTimePerDay: TimeInterval {
//        let pctInForeground = totalForegroundTime / totalUptime
//        return (60 * 60 * 24) * pctInForeground
//    }

    static var hasBeenTerminatedToday: Bool {
        guard let last = highlander[.lastTerminatedDate] as? Date else { return false }
        return last.age < .oneDay
    }

    // MARK: - Onboarding

    static var needsOnboarding: Bool {
        if !LocomotionManager.highlander.haveLocationPermission { return true }
        if !haveCoreMotionPermission && !haveRequestedMotionPermissions { return true }
        if !haveHealthKitPermission && !haveRequestedHealthPermissions { return true }
        return false
    }

    // MARK: - Permissions

    static var notificationsPermission: UNAuthorizationStatus?

    static var haveRequestedMotionPermissions: Bool {
        get { return highlander[.haveRequestedMotionPermissions] as? Bool ?? false }
        set(newValue) { highlander[.haveRequestedMotionPermissions] = newValue }
    }

    static var haveNecessaryPermissions: Bool {
        if !LocomotionManager.highlander.haveBackgroundLocationPermission { return false }
        if UIApplication.shared.backgroundRefreshStatus != .available { return false }
        if notificationsPermission != .authorized { return false }
        return true
    }

    static var haveCoreMotionPermission: Bool {
        return LocomotionManager.highlander.haveCoreMotionPermission
    }

    static var shouldAttemptToUseCoreMotion: Bool {
        return haveCoreMotionPermission || haveRequestedMotionPermissions
    }

    static var haveRequestedHealthPermissions: Bool {
        get { return highlander[.haveRequestedHealthPermissions] as? Bool ?? false }
        set(newValue) { highlander[.haveRequestedHealthPermissions] = newValue }
    }

    static func requestHealthKitPermissions() {
        Health.highlander.requestPermissions()
        haveRequestedHealthPermissions = true
    }

    static func requestNotificationPerms() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge]) { granted, error in
            self.determineNotificationsPerms()
        }
    }

    static func determineNotificationsPerms() {
        guard notificationsPermission == nil else { return }
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            self.notificationsPermission = settings.authorizationStatus
        }
    }

    static var haveHealthKitPermission: Bool {
        if !HKHealthStore.isHealthDataAvailable() { return true }
        for permission in Health.readPermissions.values {
            if !permission { return false }
        }
        return true
    }

    static var shouldRequestNotificationPermission: Bool {
        guard let perms = notificationsPermission else { return true }
        return perms == .notDetermined
    }

    static var haveNotificationsPermission: Bool {
        return notificationsPermission == .authorized
    }
    
    static var canFoursquare: Bool = { return UIApplication.shared.canOpenURL(URL(string: "foursquare://")!) }()
    static var canSwarm: Bool = { return UIApplication.shared.canOpenURL(URL(string: "swarm://")!) }()
    static var haveFoursquareAuth: Bool { return Settings.highlander[.foursquareToken] != nil }

    // MARK: - Email debug info

    public static var emailFooter: String {
        return "\n\n\n"
            + "---------\n"
            + debugDeviceString + "\n"
            + debugProblemsString + "\n"
            + debugString + "\n"
            + "i: \(UIDevice.current.identifierForVendor?.uuidString ?? "nil")\n\n"
    }

    private static var debugDeviceString: String {
        return "arc: \(Bundle.versionNumber) (\(Bundle.buildNumber)), "
            + "dev: \(UIDevice.current.modelCode) (\(UIDevice.current.systemVersion))"
    }

    private static var debugProblemsString: String {
        return ""
            .appendingCode("bl", boolValue: LocomotionManager.highlander.haveBackgroundLocationPermission, safeValue: true)
            .appendingCode("br", boolValue: UIApplication.shared.backgroundRefreshStatus == .available, safeValue: true)
            .appendingCode("no", boolValue: notificationsPermission == .authorized, safeValue: true)
    }

    private static var debugString: String {
        return "ro: \(Settings.recordingOn), "
            + "cs: \(Settings.sharingOn)\n"
    }

    // MARK: - Item getters

    static var dataDateRange: DateInterval {
        return DateInterval(start: firstDate.startOfDay, end: Date())
    }
    static var firstDate: Date {
        guard let firstItemStartDate = firstTimelineItem?.startDate else { return Date() }
        return firstItemStartDate > earliestAllowedDate ? firstItemStartDate : earliestAllowedDate
    }

    static var _firstTimelineItem: TimelineItem?
    static var firstTimelineItem: TimelineItem? {
        if let cached = _firstTimelineItem, !cached.deleted, cached.startDate != nil { return cached }
        let firstItem = RecordingManager.store.item(where: "startDate IS NOT NULL AND deleted = 0 ORDER BY startDate")
        _firstTimelineItem = firstItem
        return _firstTimelineItem
    }

    // MARK: - Private settings getters

    static let foursquareClientId: String? = {
        return Bundle.main.infoDictionary?["FoursquareClientId"] as? String
    }()

    static let foursquareClientSecret: String? = {
        return Bundle.main.infoDictionary?["FoursquareClientSecret"] as? String
    }()

    static let lastFmAPIKey: String? = {
        return Bundle.main.infoDictionary?["LastFmAPIKey"] as? String
    }()

    // MARK: - Subscript

    subscript(key: SettingsKey) -> Any? {
        get { return UserDefaults.standard.value(forKey: key.rawValue) as Any? }
        set(value) { UserDefaults.standard.set(value, forKey: key.rawValue) }
    }

}

extension String {
    fileprivate func appendingCode(_ code: String, boolValue: Bool, safeValue: Bool) -> String {
        var mutated = self
        if !mutated.isEmpty { mutated += ", " }
        mutated += "\(code): \(boolValue)"
        if boolValue != safeValue { mutated += "*" }
        return mutated
    }
}
