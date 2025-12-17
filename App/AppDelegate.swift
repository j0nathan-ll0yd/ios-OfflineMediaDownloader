import Foundation
import SwiftUI
import ComposableArchitecture
import UserNotifications
import AVFoundation

class AppDelegate: NSObject, UIApplicationDelegate {
  let store = Store(initialState: RootFeature.State()) {
    #if DEBUG
    RootFeature()._printChanges()
    #else
    RootFeature()
    #endif
  }

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
}
