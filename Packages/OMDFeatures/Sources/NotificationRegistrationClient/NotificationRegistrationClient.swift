import ComposableArchitecture
import UIKit

@DependencyClient
public struct NotificationRegistrationClient: Sendable {
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
    registerForRemoteNotifications: {
      await MainActor.run {
        UIApplication.shared.registerForRemoteNotifications()
      }
    }
  )

  public static let testValue = Self(
    registerForRemoteNotifications: {}
  )
}
