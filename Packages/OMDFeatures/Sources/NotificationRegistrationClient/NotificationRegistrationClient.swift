import ComposableArchitecture
import UIKit
import UserNotifications

@DependencyClient
public struct NotificationRegistrationClient: Sendable {
  /// Asks for alert, sound and badge permission. Returns `true` when notifications are authorized.
  public var requestAuthorization: @Sendable () async -> Bool = { false }
  public var registerForRemoteNotifications: @Sendable () async -> Void
}

public extension DependencyValues {
  var notificationRegistrationClient: NotificationRegistrationClient {
    get { self[NotificationRegistrationClient.self] }
    set { self[NotificationRegistrationClient.self] = newValue }
  }
}

extension NotificationRegistrationClient: DependencyKey {
  public static let liveValue = Self(
    requestAuthorization: {
      let center = UNUserNotificationCenter.current()
      guard await (try? center.requestAuthorization(options: [.alert, .sound, .badge])) == true else {
        return false
      }
      return await center.notificationSettings().authorizationStatus == .authorized
    },
    registerForRemoteNotifications: {
      await MainActor.run {
        UIApplication.shared.registerForRemoteNotifications()
      }
    }
  )

  public static let testValue = Self(
    requestAuthorization: { false },
    registerForRemoteNotifications: {}
  )
}
