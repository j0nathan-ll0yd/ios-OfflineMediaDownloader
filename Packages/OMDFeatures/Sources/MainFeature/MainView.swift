import ActiveDownloadsFeature
import ComposableArchitecture
import DesignSystem
import DiagnosticFeature
import FileListFeature
import LoginFeature
import SwiftUI

public struct MainView: View {
  @Bindable var store: StoreOf<MainFeature>

  private let theme = DarkProfessionalTheme()

  public init(store: StoreOf<MainFeature>) {
    self.store = store
  }

  public var body: some View {
    ZStack(alignment: .bottom) {
      TabView(selection: $store.selectedTab.sending(\.tabSelected)) {
        FileListView(store: store.scope(state: \.fileList, action: \.fileList))
          .tabItem {
            Label("Files", systemImage: "film.stack")
          }
          .tag(MainFeature.State.Tab.files)

        accountTabContent
          .id(store.isAuthenticated)
          .tabItem {
            Label("Account", systemImage: "person.crop.circle")
          }
          .tag(MainFeature.State.Tab.account)
      }
      .tint(theme.primaryColor)

      // Active downloads banner - positioned above tab bar
      VStack {
        Spacer()
        ActiveDownloadsBanner(
          store: store.scope(state: \.activeDownloads, action: \.activeDownloads)
        )
        .padding(.bottom, 49) // Tab bar height
      }
    }
    .preferredColorScheme(.dark)
    .sheet(item: $store.scope(state: \.loginSheet, action: \.loginSheet)) { loginStore in
      NavigationStack {
        LoginView(store: loginStore)
          .toolbar {
            ToolbarItem(placement: .topBarLeading) {
              Button("Cancel") {
                store.send(.loginSheet(.dismiss))
              }
              .foregroundStyle(.white)
            }
          }
      }
    }
  }

  @ViewBuilder
  private var accountTabContent: some View {
    if store.isAuthenticated {
      DiagnosticView(store: store.scope(state: \.diagnostic, action: \.diagnostic))
    } else {
      LoginView(store: store.scope(state: \.accountLogin, action: \.accountLogin))
    }
  }
}
