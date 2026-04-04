import Dependencies
import DependenciesMacros
import Foundation
import os.log

// MARK: - Analytics Events

/// Predefined analytics events for the app
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

  // Files
  case fileListLoaded = "file_list_loaded"
  case fileAddStarted = "file_add_started"
  case fileAddCompleted = "file_add_completed"
  case fileAddFailed = "file_add_failed"
  case fileDeleted = "file_deleted"

  // Downloads
  case downloadStarted = "download_started"
  case downloadCompleted = "download_completed"
  case downloadFailed = "download_failed"
  case downloadCancelled = "download_cancelled"

  // Playback
  case playbackStarted = "playback_started"
  case playbackCompleted = "playback_completed"
  case playbackError = "playback_error"

  // Push Notifications
  case pushRegistered = "push_registered"
  case pushReceived = "push_received"
  case pushOpened = "push_opened"

  // Errors
  case errorDisplayed = "error_displayed"
  case networkError = "network_error"
  case authError = "auth_error"
}

// MARK: - Analytics Client

/// Placeholder analytics client for future integration with analytics services
/// (e.g., Firebase Analytics, Mixpanel, Amplitude)
@DependencyClient
public struct AnalyticsClient: Sendable {
  public var track: @Sendable (AnalyticsEvent, [String: String]?) -> Void = { _, _ in }
  public var setUserId: @Sendable (String?) -> Void = { _ in }
  public var setUserProperty: @Sendable (String, String?) -> Void = { _, _ in }
  public var screenView: @Sendable (String) -> Void = { _ in }
}

// MARK: - Convenience Methods

extension AnalyticsClient {
  public func track(_ event: AnalyticsEvent) {
    track(event, nil)
  }

  public func trackFileEvent(
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

  public func trackError(_ event: AnalyticsEvent, errorType: String, message: String) {
    track(event, [
      "error_type": errorType,
      "error_message": message
    ])
  }
}

// MARK: - Debug Console Logger

/// os.log-based analytics logging for DEBUG builds (avoids print() to comply with S47)
private let analyticsLog = OSLog(subsystem: "OfflineMediaDownloader", category: "Analytics")

// MARK: - Live Implementation

extension AnalyticsClient: DependencyKey {
  public static let liveValue: AnalyticsClient = {
    return AnalyticsClient(
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
      }
    )
  }()

  public static let testValue = AnalyticsClient()
}

extension DependencyValues {
  public var analytics: AnalyticsClient {
    get { self[AnalyticsClient.self] }
    set { self[AnalyticsClient.self] = newValue }
  }
}
