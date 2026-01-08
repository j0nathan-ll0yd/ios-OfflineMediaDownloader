//
//  OfflineMediaDownloaderApp.swift
//  OfflineMediaDownloader
//
//  Created by Jonathan Lloyd on 10/21/24.
//

import SwiftUI
import ComposableArchitecture
import Network

@main
struct OfflineMediaDownloaderApp: App {
  @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

  var body: some Scene {
    WindowGroup {
      if CommandLine.arguments.contains("-showPreviewCatalog") {
        RedesignPreviewCatalog()
      } else {
        AppContentView(store: appDelegate.store)
      }
    }
  }
}

/// Wrapper view that handles scene phase changes to refresh file list on foreground
private struct AppContentView: View {
  let store: StoreOf<RootFeature>
  @SwiftUI.Environment(\.scenePhase) private var scenePhase: ScenePhase
  @State private var hasLaunched = false

  var body: some View {
    RootView(store: store)
      .onChange(of: scenePhase) { _, newPhase in
        if newPhase == .active {
          if hasLaunched {
            // Returning from background - refresh if we have connectivity
            refreshIfConnected()
          }
          hasLaunched = true
        }
      }
  }

  private func refreshIfConnected() {
    let monitor = NWPathMonitor()
    monitor.pathUpdateHandler = { path in
      monitor.cancel()
      if path.status == .satisfied {
        Task { @MainActor in
          store.send(.main(.fileList(.onAppear)))
        }
      }
    }
    monitor.start(queue: DispatchQueue.global(qos: .utility))
  }
}
