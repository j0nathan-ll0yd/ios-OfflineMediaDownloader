import ComposableArchitecture
import UIKit

@DependencyClient
struct NotificationRegistrationClient: Sendable {
    var registerForRemoteNotifications: @Sendable () async -> Void
}

extension DependencyValues {
    var notificationRegistrationClient: NotificationRegistrationClient {
        get { self[NotificationRegistrationClient.self] }
        set { self[NotificationRegistrationClient.self] = newValue }
    }
}

extension NotificationRegistrationClient: DependencyKey {
    static let liveValue = Self(
        registerForRemoteNotifications: {
            await MainActor.run {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    )

    static let testValue = Self(
        registerForRemoteNotifications: {}
    )
}
