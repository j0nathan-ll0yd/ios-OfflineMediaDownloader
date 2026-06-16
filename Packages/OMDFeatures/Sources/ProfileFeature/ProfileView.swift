import ComposableArchitecture
import DesignSystem
#if DEBUG
  import DiagnosticFeature
#endif
import LifegamesComponents
import LifegamesComponentsCore
import LifegamesTemplates
import LifegamesTokens
import PersistenceClient
import SharedModels
import SwiftUI

/// Authenticated Account screen rendered on the Lifegames `ProfileTemplate`.
///
/// `ProfileTemplate` owns its OWN `ScrollView`, so the `content` slot is a plain
/// `VStack` of molecules (stat cards + setting rows) — NO nested `List` /
/// `SettingsTemplate` / outer `ScrollView` (R4, avoids double-scroll). Identity
/// and the three CoreData stats come from `ProfileFeature`; navigation + sign-out
/// are delegated up to `MainFeature`.
public struct ProfileView: View {
  @Bindable var store: StoreOf<ProfileFeature>

  public init(store: StoreOf<ProfileFeature>) {
    self.store = store
  }

  public var body: some View {
    ProfileTemplate(accent: OMDPalette.playback) {
      header
    } content: {
      VStack(spacing: Spacing.s500) {
        statsRow
        rows
      }
    }
    .task { store.send(.onAppear) }
  }

  // MARK: - Header (identity)

  private var header: some View {
    VStack(spacing: Spacing.s400) {
      InitialsAvatarView(initials: initials, accent: OMDPalette.playback, size: 80)

      VStack(spacing: Spacing.s100) {
        Text(displayName)
          .font(OMDFont.bold(22))
          .foregroundStyle(LGColor.textTitle)

        Text(displayEmail)
          .font(OMDFont.regular(14))
          .foregroundStyle(OMDPalette.playback)
      }
    }
    .padding(Spacing.s400)
    .frame(maxWidth: .infinity)
    .neonCard(accent: OMDPalette.playback)
  }

  // MARK: - Stats

  private var statsRow: some View {
    HStack(spacing: Spacing.s300) {
      statCard(
        label: "Downloads",
        value: "\(store.metrics?.downloadCount ?? 0)",
        systemImage: "arrow.down.circle.fill"
      )
      statCard(
        label: "Storage",
        value: formattedStorageSize,
        systemImage: "internaldrive.fill"
      )
      statCard(
        label: "Watched",
        value: "\(store.metrics?.playCount ?? 0)",
        systemImage: "play.circle.fill"
      )
    }
  }

  private func statCard(label: String, value: String, systemImage: String) -> some View {
    MetricContentView(
      label: label,
      value: value,
      systemImage: systemImage,
      accent: OMDPalette.playback
    )
    .frame(maxWidth: .infinity)
    .neonCard(accent: OMDPalette.playback)
  }

  // MARK: - Rows + Sign Out

  private var rows: some View {
    VStack(spacing: Spacing.s300) {
      Button {
        store.send(.downloadSettingsTapped)
      } label: {
        SettingRowView(
          systemImage: "arrow.down.circle",
          label: "Download Settings",
          accessory: .chevron,
          accent: OMDPalette.playback
        )
        .contentShape(.rect)
      }
      .buttonStyle(.plain)

      #if DEBUG
        DiagnosticSection(
          store: store.scope(state: \.diagnostic, action: \.diagnostic)
        )
        .padding(.top, Spacing.s200)
      #endif

      LGButton("Sign Out", variant: .destructive) {
        store.send(.signOutTapped)
      }
      .padding(.top, Spacing.s200)
    }
  }

  // MARK: - Identity helpers

  private var displayName: String {
    guard let user = store.user else { return "Account" }
    let full = "\(user.firstName) \(user.lastName)".trimmingCharacters(in: .whitespaces)
    return full.isEmpty ? "Account" : full
  }

  private var displayEmail: String {
    let email = store.user?.email ?? ""
    return email.isEmpty ? "No email" : email
  }

  private var initials: String {
    let first = store.user?.firstName.first.map(String.init) ?? ""
    let last = store.user?.lastName.first.map(String.init) ?? ""
    let combined = "\(first)\(last)".uppercased()
    if !combined.isEmpty { return combined }
    if let emailInitial = store.user?.email.first.map(String.init) {
      return emailInitial.uppercased()
    }
    return "?"
  }

  // MARK: - Storage formatting (mirrors DiagnosticView)

  private var formattedStorageSize: String {
    let bytes = store.metrics?.totalStorageBytes ?? 0
    if bytes == 0 {
      return "0 MB"
    } else if bytes < 1_000_000 {
      return String(format: "%.0f KB", Double(bytes) / 1000)
    } else if bytes < 1_000_000_000 {
      return String(format: "%.1f MB", Double(bytes) / 1_000_000)
    } else {
      return String(format: "%.2f GB", Double(bytes) / 1_000_000_000)
    }
  }
}

#Preview {
  ProfileView(
    store: Store(
      initialState: ProfileFeature.State(
        user: User(email: "ada@example.com", firstName: "Ada", identifier: "id-1", lastName: "Lovelace"),
        metrics: FileMetrics(downloadCount: 12, totalStorageBytes: 2_400_000_000, playCount: 47)
      )
    ) {
      ProfileFeature()
    }
  )
  .preferredColorScheme(.dark)
}
