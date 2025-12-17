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

      DiagnosticView(store: store.scope(state: \.diagnostic, action: \.diagnostic))
        .tabItem {
          Label("Account", systemImage: "person.crop.circle")
        }
        .tag(MainFeature.State.Tab.account)
    }
  }
}

#Preview {
  MainView(store: Store(initialState: MainFeature.State()) {
    MainFeature()
  })
}
