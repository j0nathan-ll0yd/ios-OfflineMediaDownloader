import ComposableArchitecture
import DesignSystem
import LifegamesTemplates
import LifegamesTokens
import SwiftUI

public struct NotificationsView: View {
  @Bindable var store: StoreOf<NotificationsFeature>

  public init(store: StoreOf<NotificationsFeature>) {
    self.store = store
  }

  public var body: some View {
    SettingsTemplate(
      sections: [
        SettingsTemplate.Section(
          title: "Alerts",
          footer: "Choose which alerts you'd like to receive on this device.",
          rows: [
            .toggle(
              label: "Download Complete",
              systemImage: "checkmark.circle.fill",
              isOn: Binding(
                get: { store.downloadComplete },
                set: { store.send(.downloadCompleteToggled($0)) }
              )
            ),
            .toggle(
              label: "New Content Available",
              systemImage: "sparkles",
              isOn: Binding(
                get: { store.newContent },
                set: { store.send(.newContentToggled($0)) }
              )
            ),
            .toggle(
              label: "Product Updates",
              systemImage: "megaphone.fill",
              isOn: Binding(
                get: { store.productUpdates },
                set: { store.send(.productUpdatesToggled($0)) }
              )
            ),
          ]
        ),
      ],
      accent: OMDPalette.primary
    )
    .background(LGColor.surfaceBase.ignoresSafeArea())
    .navigationTitle("Notifications")
    #if os(iOS)
      .navigationBarTitleDisplayMode(.inline)
      .toolbarColorScheme(.dark, for: .navigationBar)
    #endif
      .preferredColorScheme(.dark)
  }
}

#Preview {
  NavigationStack {
    NotificationsView(
      store: Store(initialState: NotificationsFeature.State()) {
        NotificationsFeature()
      }
    )
  }
  .preferredColorScheme(.dark)
}
