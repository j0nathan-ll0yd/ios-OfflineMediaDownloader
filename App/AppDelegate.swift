import Foundation
import SwiftUI
import ComposableArchitecture
import UserNotifications
import AVFoundation

class AppDelegate: NSObject, UIApplicationDelegate {
  /// Check if running as a test host (unit tests hosted by the app)
  private static var isRunningTests: Bool {
    ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil ||
    NSClassFromString("XCTestCase") != nil
  }

  /// Store is lazy to avoid initialization when running as test host
  lazy var store: StoreOf<RootFeature> = {
    // When running tests, use a minimal store with test dependencies
    if Self.isRunningTests {
      return Store(initialState: RootFeature.State()) {
        RootFeature()
      } withDependencies: {
        // Override dependencies that may crash in test environment
        $0.authenticationClient = .testValue
        $0.keychainClient = KeychainClient(
          getUserData: { throw KeychainError.unableToStore },
          getJwtToken: { nil },
          getTokenExpiresAt: { nil },
          getDeviceData: { nil },
          getUserIdentifier: { nil },
          setUserData: { _ in },
          setJwtToken: { _ in },
          setTokenExpiresAt: { _ in },
          setDeviceData: { _ in },
          deleteUserData: { },
          deleteJwtToken: { },
          deleteTokenExpiresAt: { },
          deleteDeviceData: { }
        )
        $0.serverClient = .testValue
        $0.coreDataClient = .testValue
        $0.downloadClient = .testValue
        $0.fileClient = .testValue
        $0.logger = .testValue
      }
    }

    #if DEBUG
    return Store(initialState: RootFeature.State()) {
      RootFeature()._printChanges()
    }
    #else
    return Store(initialState: RootFeature.State()) {
      RootFeature()
    }
    #endif
  }()

  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
  ) -> Bool {
    // Configure audio session for video playback
    let audioSession = AVAudioSession.sharedInstance()
    do {
      try audioSession.setCategory(.playback, mode: .moviePlayback)
    } catch {
      print("Setting audio session category failed: \(error)")
    }

    store.send(.didFinishLaunching)
    return true
  }

  func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
    store.send(.didRegisterForRemoteNotificationsWithDeviceToken(token))
  }

  func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    store.send(.didFailToRegisterForRemoteNotificationsWithError(error))
  }

  func application(
    _ application: UIApplication,
    didReceiveRemoteNotification userInfo: [AnyHashable: Any],
    fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
  ) {
    print("📥 Received push notification: \(userInfo)")
    // Send to TCA store for processing
    store.send(.receivedPushNotification(userInfo))
    completionHandler(.newData)
  }

  func application(
    _ application: UIApplication,
    handleEventsForBackgroundURLSession identifier: String,
    completionHandler: @escaping () -> Void
  ) {
    print("📥 AppDelegate: handleEventsForBackgroundURLSession called with identifier: \(identifier)")
    // Re-initialize DownloadManager if needed (it's a singleton, so accessing .shared ensures it's initialized)
    // Pass the completion handler to DownloadManager
    Task {
      await DownloadManager.shared.setBackgroundCompletionHandler(completionHandler)
    }
  }
}
