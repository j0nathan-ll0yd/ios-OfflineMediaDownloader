import SwiftUI
import ComposableArchitecture

struct MainView: View {
  @Bindable var store: StoreOf<MainFeature>

  var body: some View {
    TabView(selection: $store.selectedTab.sending(\.tabSelected)) {
      FileListView(store: store.scope(state: \.fileList, action: \.fileList))
        .tabItem {
          Label("Files", systemImage: "list.bullet")
        }
        .tag(MainFeature.State.Tab.files)
        .accessibilityIdentifier("filesTab")

      accountTabContent
        .tabItem {
          Label("Account", systemImage: "person.crop.circle")
        }
        .tag(MainFeature.State.Tab.account)
        .accessibilityIdentifier("diagnosticsTab")
    }
    .sheet(item: $store.scope(state: \.loginSheet, action: \.loginSheet)) { loginStore in
      NavigationStack {
        LoginView(store: loginStore)
          .toolbar {
            ToolbarItem(placement: .topBarLeading) {
              Button("Cancel") {
                store.send(.loginSheet(.dismiss))
              }
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
      UnauthenticatedAccountView {
        store.send(.presentLoginSheet)
      }
    }
  }
}

#Preview {
  MainView(store: Store(initialState: MainFeature.State()) {
    MainFeature()
  })
}
