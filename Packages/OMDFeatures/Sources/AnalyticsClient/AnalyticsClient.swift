import Dependencies
import DependenciesMacros
import Foundation
import os.log
import UIKit

// MARK: - Analytics Events

public enum AnalyticsEvent: String, Sendable {
  // Lifecycle
  case appLaunched = "app_launched"
  case appBackgrounded = "app_backgrounded"
  case appForegrounded = "app_foregrounded"

  // Authentication
  case loginStarted = "login_started"
  case loginCompleted = "login_completed"
  case loginFailed = "login_failed"
  case registrationCompleted = "registration_completed"
  case logoutCompleted = "logout_completed"
  case sessionExpired = "session_expired"
  case tokenRefreshSucceeded = "token_refresh_succeeded"
  case tokenRefreshFailed = "token_refresh_failed"

  // Files
  case fileListLoaded = "file_list_loaded"
  case fileAddStarted = "file_add_started"
  case fileAddCompleted = "file_add_completed"
  case fileAddFailed = "file_add_failed"
  case fileDeleted = "file_deleted"
  case fileSyncMismatch = "file_sync_mismatch"

  // Downloads
  case downloadStarted = "download_started"
  case downloadCompleted = "download_completed"
  case downloadCompletedLocally = "download_completed_locally"
  case downloadFailed = "download_failed"
  case downloadCancelled = "download_cancelled"

  // Playback
  case playbackStarted = "playback_started"
  case playbackCompleted = "playback_completed"
  case playbackError = "playback_error"

  // Push Notifications
  case pushRegistered = "push_registered"
  case pushDelivered = "push_delivered"
  case pushReceived = "push_received"
  case pushOpened = "push_opened"

  // Background Tasks
  case backgroundTaskCompleted = "background_task_completed"
  case backgroundTaskExpired = "background_task_expired"

  // Errors
  case errorDisplayed = "error_displayed"
  case networkError = "network_error"
  case authError = "auth_error"
  case certificatePinningFailed = "certificate_pinning_failed"
}

// MARK: - Analytics Client

@DependencyClient
public struct AnalyticsClient: Sendable {
  public var track: @Sendable (AnalyticsEvent, [String: String]?) -> Void = { _, _ in }
  public var setUserId: @Sendable (String?) -> Void = { _ in }
  public var setUserProperty: @Sendable (String, String?) -> Void = { _, _ in }
  public var screenView: @Sendable (String) -> Void = { _ in }
  public var flush: @Sendable () async -> Void = {}
}

// MARK: - Convenience Methods

public extension AnalyticsClient {
  func track(_ event: AnalyticsEvent) {
    track(event, nil)
  }

  func trackFileEvent(
    _ event: AnalyticsEvent,
    fileId: String,
    fileName: String? = nil,
    fileSize: Int? = nil
  ) {
    var properties: [String: String] = ["file_id": fileId]
    if let fileName { properties["file_name"] = fileName }
    if let fileSize { properties["file_size"] = String(fileSize) }
    track(event, properties)
  }

  func trackError(_ event: AnalyticsEvent, errorType: String, message: String) {
    track(event, [
      "error_type": errorType,
      "error_message": message,
    ])
  }

  func trackAppLaunched() {
    var sysinfo = utsname()
    uname(&sysinfo)
    let model = withUnsafePointer(to: &sysinfo.machine) {
      $0.withMemoryRebound(to: CChar.self, capacity: 1) { String(cString: $0) }
    }
    let version = ProcessInfo.processInfo.operatingSystemVersion
    track(.appLaunched, [
      "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
      "buildNumber": Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown",
      "osVersion": "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)",
      "deviceModel": model,
    ])
  }

  func trackPushReceived(correlationId: String, notificationType: String?) {
    var properties: [String: String] = ["correlationId": correlationId]
    if let notificationType { properties["notificationType"] = notificationType }
    track(.pushReceived, properties)
  }
}

// MARK: - Event Mapping

private func mapToClientEvent(
  _ event: AnalyticsEvent,
  properties: [String: String]?
) -> ClientEvent? {
  let now = Date()

  switch event {
  case .pushDelivered:
    guard let correlationId = properties?["correlationId"] else { return nil }
    return .pushDelivered(timestamp: now, correlationId: correlationId, notificationType: properties?["notificationType"])

  case .pushReceived:
    guard let correlationId = properties?["correlationId"] else { return nil }
    return .pushReceived(timestamp: now, correlationId: correlationId, notificationType: properties?["notificationType"])

  case .pushOpened:
    guard let correlationId = properties?["correlationId"] else { return nil }
    return .pushOpened(timestamp: now, correlationId: correlationId, notificationType: properties?["notificationType"])

  case .downloadCompletedLocally:
    guard let fileId = properties?["fileId"],
          let fileSizeBytes = properties?["fileSizeBytes"].flatMap(Int.init),
          let durationMs = properties?["durationMs"].flatMap(Int.init) else { return nil }
    return .downloadCompletedLocally(timestamp: now, fileId: fileId, fileSizeBytes: fileSizeBytes, durationMs: durationMs)

  case .playbackStarted:
    guard let fileId = properties?["fileId"] else { return nil }
    return .playbackStarted(timestamp: now, fileId: fileId, durationSec: properties?["durationSec"].flatMap(Double.init))

  case .playbackCompleted:
    guard let fileId = properties?["fileId"],
          let playbackDurationSec = properties?["playbackDurationSec"].flatMap(Double.init) else { return nil }
    return .playbackCompleted(timestamp: now, fileId: fileId, playbackDurationSec: playbackDurationSec)

  case .fileSyncMismatch:
    guard let localCount = properties?["localCount"].flatMap(Int.init),
          let serverCount = properties?["serverCount"].flatMap(Int.init) else { return nil }
    let missingFileIds = properties?["missingFileIds"]?.components(separatedBy: ",").filter { !$0.isEmpty }
    return .fileSyncMismatch(timestamp: now, localCount: localCount, serverCount: serverCount, missingFileIds: missingFileIds)

  case .certificatePinningFailed:
    guard let host = properties?["host"],
          let errorMessage = properties?["errorMessage"] else { return nil }
    return .certificatePinningFailed(timestamp: now, host: host, errorMessage: errorMessage)

  case .tokenRefreshSucceeded:
    return .tokenRefreshSucceeded(timestamp: now, sessionId: properties?["sessionId"])

  case .tokenRefreshFailed:
    guard let errorType = properties?["errorType"],
          let errorMessage = properties?["errorMessage"] else { return nil }
    return .tokenRefreshFailed(timestamp: now, errorType: errorType, errorMessage: errorMessage)

  case .sessionExpired:
    return .sessionExpired(timestamp: now, sessionId: properties?["sessionId"])

  case .backgroundTaskCompleted:
    guard let taskName = properties?["taskName"],
          let durationMs = properties?["durationMs"].flatMap(Int.init) else { return nil }
    return .backgroundTaskCompleted(timestamp: now, taskName: taskName, durationMs: durationMs)

  case .backgroundTaskExpired:
    guard let taskName = properties?["taskName"] else { return nil }
    return .backgroundTaskExpired(timestamp: now, taskName: taskName)

  case .appLaunched:
    guard let appVersion = properties?["appVersion"],
          let buildNumber = properties?["buildNumber"],
          let osVersion = properties?["osVersion"],
          let deviceModel = properties?["deviceModel"] else { return nil }
    return .appLaunched(timestamp: now, appVersion: appVersion, buildNumber: buildNumber, osVersion: osVersion, deviceModel: deviceModel)

  case .networkError:
    guard let endpoint = properties?["endpoint"],
          let errorMessage = properties?["errorMessage"] else { return nil }
    return .networkError(timestamp: now, endpoint: endpoint, statusCode: properties?["statusCode"].flatMap(Int.init), errorMessage: errorMessage)

  default:
    return nil
  }
}

// MARK: - Debug Console Logger

private let analyticsLog = OSLog(subsystem: "OfflineMediaDownloader", category: "Analytics")

// MARK: - Live Implementation

extension AnalyticsClient: DependencyKey {
  public static let liveValue: AnalyticsClient = {
    let deviceId = MainActor.assumeIsolated {
      UIDevice.current.identifierForVendor?.uuidString ?? ""
    }
    UserDefaults(suiteName: "group.lifegames.OfflineMediaDownloader")?.set(deviceId, forKey: "deviceUUID")
    let buffer = EventBuffer(flushHandler: EventBuffer.makeFlushHandler(deviceId: deviceId))
    Task { await buffer.start() }

    return .init(
      track: { event, properties in
        #if DEBUG
          let propsString = properties.map { dict in
            dict.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
          } ?? ""
          if propsString.isEmpty {
            os_log("[Analytics] %{public}@", log: analyticsLog, type: .debug, event.rawValue)
          } else {
            os_log("[Analytics] %{public}@ {%{public}@}", log: analyticsLog, type: .debug, event.rawValue, propsString)
          }
        #endif

        if let clientEvent = mapToClientEvent(event, properties: properties) {
          Task { await buffer.append(clientEvent) }
        }

        if event == .appBackgrounded {
          Task { await buffer.flush() }
        }
      },
      setUserId: { userId in
        #if DEBUG
          os_log("[Analytics] Set user ID: %{public}@", log: analyticsLog, type: .debug, userId ?? "nil")
        #endif
      },
      setUserProperty: { name, value in
        #if DEBUG
          os_log("[Analytics] Set user property %{public}@: %{public}@", log: analyticsLog, type: .debug, name, value ?? "nil")
        #endif
      },
      screenView: { screenName in
        #if DEBUG
          os_log("[Analytics] Screen view: %{public}@", log: analyticsLog, type: .debug, screenName)
        #endif
      },
      flush: {
        await buffer.flush()
      }
    )
  }()

  public static let testValue = AnalyticsClient()
}

public extension DependencyValues {
  var analytics: AnalyticsClient {
    get { self[AnalyticsClient.self] }
    set { self[AnalyticsClient.self] = newValue }
  }
}
