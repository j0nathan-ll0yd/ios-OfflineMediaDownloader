//
//  OfflineMediaDownloaderApp.swift
//  OfflineMediaDownloader
//
//  Created by Jonathan Lloyd on 10/21/24.
//

import SwiftUI
import ComposableArchitecture

@main
struct OfflineMediaDownloaderApp: App {
  @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

  var body: some Scene {
    WindowGroup {
      AppContentView(store: appDelegate.store)
    }
  }
}

/// Wrapper view that handles scene phase changes to refresh file list on foreground
private struct AppContentView: View {
  let store: StoreOf<RootFeature>
  @SwiftUI.Environment(\.scenePhase) private var scenePhase: ScenePhase

  var body: some View {
    RootView(store: store)
      .onChange(of: scenePhase) { _, newPhase in
        if newPhase == .active {
          // Refresh file list to pick up any background downloads
          store.send(.main(.fileList(.onAppear)))
        }
      }
  }
}
