import Dependencies
import DependenciesMacros
import Foundation

// MARK: - Analytics Events

/// Predefined analytics events for the app
enum AnalyticsEvent: String, Sendable {
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
struct AnalyticsClient: Sendable {
  var track: @Sendable (AnalyticsEvent, [String: String]?) -> Void = { _, _ in }
  var setUserId: @Sendable (String?) -> Void = { _ in }
  var setUserProperty: @Sendable (String, String?) -> Void = { _, _ in }
  var screenView: @Sendable (String) -> Void = { _ in }
}

// MARK: - Convenience Methods

extension AnalyticsClient {
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
      "error_message": message
    ])
  }
}

// MARK: - Live Implementation

extension AnalyticsClient: DependencyKey {
  /// Placeholder implementation that logs to console in DEBUG
  /// Replace with actual analytics service integration when ready
  static let liveValue: AnalyticsClient = {
    return AnalyticsClient(
      track: { event, properties in
        #if DEBUG
        let propsString = properties.map { dict in
          dict.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
        } ?? ""
        if propsString.isEmpty {
          print("📈 [Analytics] \(event.rawValue)")
        } else {
          print("📈 [Analytics] \(event.rawValue) {\(propsString)}")
        }
        #endif

        // TODO: Replace with actual analytics SDK call
        // Example with Firebase:
        // Analytics.logEvent(event.rawValue, parameters: properties)
        //
        // Example with Mixpanel:
        // Mixpanel.mainInstance().track(event: event.rawValue, properties: properties)
      },
      setUserId: { userId in
        #if DEBUG
        print("📈 [Analytics] Set user ID: \(userId ?? "nil")")
        #endif
        // TODO: Analytics.setUserID(userId)
      },
      setUserProperty: { name, value in
        #if DEBUG
        print("📈 [Analytics] Set user property \(name): \(value ?? "nil")")
        #endif
        // TODO: Analytics.setUserProperty(value, forName: name)
      },
      screenView: { screenName in
        #if DEBUG
        print("📈 [Analytics] Screen view: \(screenName)")
        #endif
        // TODO: Analytics.logEvent(AnalyticsEventScreenView, parameters: [...])
      }
    )
  }()

  static let testValue = AnalyticsClient()
}

extension DependencyValues {
  var analytics: AnalyticsClient {
    get { self[AnalyticsClient.self] }
    set { self[AnalyticsClient.self] = newValue }
  }
}
