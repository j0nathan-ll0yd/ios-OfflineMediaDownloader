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
import PreviewFixtures
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
        statsSection
        accountSection
        supportSection
        #if DEBUG
          DiagnosticSection(
            store: store.scope(state: \.diagnostic, action: \.diagnostic)
          )
        #endif
        signOutButton
      }
    }
    .navigationTitle("Account")
    #if os(iOS)
      .navigationBarTitleDisplayMode(.inline)
      .toolbarColorScheme(.dark, for: .navigationBar)
    #endif
      .task { store.send(.onAppear) }
  }

  // MARK: - Header (identity)

  private var header: some View {
    HStack(spacing: Spacing.s400) {
      InitialsAvatarView(initials: initials, accent: OMDPalette.playback, size: 72)
        .shadow(color: LGColor.accentBlue.opacity(0.5), radius: 12)

      VStack(alignment: .leading, spacing: Spacing.s100) {
        Text(displayName)
          .font(OMDFont.bold(20))
          .foregroundStyle(LGColor.textTitle)

        Text(displayEmail)
          .font(OMDFont.mono(13))
          .foregroundStyle(LGColor.accentBlue)
          .lineLimit(1)
          .truncationMode(.middle)
      }

      Spacer(minLength: 0)
    }
    .padding(Spacing.s450)
    .neonCard(accent: OMDPalette.playback)
  }

  // MARK: - Stats ("Activity")

  private var statsSection: some View {
    VStack(alignment: .leading, spacing: Spacing.s200) {
      sectionLabel("Activity", accent: OMDPalette.primary)

      HStack(alignment: .top, spacing: Spacing.s300) {
        statCard(
          label: "Downloads",
          value: "\(store.metrics?.downloadCount ?? 0)",
          systemImage: "arrow.down.circle.fill",
          accent: OMDPalette.primary
        )
        statCard(
          label: "Storage",
          value: formattedStorageSize,
          systemImage: "internaldrive.fill",
          accent: OMDPalette.destructive
        )
        statCard(
          label: "Watched",
          value: "\(store.metrics?.playCount ?? 0)",
          systemImage: "play.circle.fill",
          accent: OMDPalette.playback
        )
      }
    }
  }

  private func statCard(label: String, value: String, systemImage: String, accent: Color) -> some View {
    MetricContentView(
      label: label,
      value: value,
      systemImage: systemImage,
      accent: accent
    )
    .frame(maxWidth: .infinity, alignment: .leading)
    .neonCard(accent: accent)
  }

  // MARK: - Account settings (Edit Profile · Notifications · Download Settings)

  private var accountSection: some View {
    settingsGroup(title: "Account", accent: OMDPalette.primary) {
      settingRowButton(icon: "person.circle", label: "Edit Profile", accent: OMDPalette.primary) {
        store.send(.editProfileTapped)
      }
      settingRowButton(icon: "bell.badge.fill", label: "Notifications", accent: OMDPalette.primary) {
        store.send(.notificationsTapped)
      }
      settingRowButton(icon: "arrow.down.circle", label: "Download Settings", accent: OMDPalette.primary) {
        store.send(.downloadSettingsTapped)
      }
    }
  }

  // MARK: - Support (rows are presentational for now — no destinations wired)

  private var supportSection: some View {
    settingsGroup(title: "Support", accent: OMDPalette.destructive) {
      SettingRowView(
        systemImage: "questionmark.circle.fill",
        label: "Help Center",
        accessory: .chevron,
        accent: OMDPalette.destructive
      )
      SettingRowView(
        systemImage: "ant.fill",
        label: "Report a Bug",
        accessory: .chevron,
        accent: OMDPalette.destructive
      )
      SettingRowView(
        systemImage: "info.circle.fill",
        label: "About",
        accessory: .value(LocalizedStringKey(appVersion)),
        accent: OMDPalette.destructive
      )
    }
  }

  // MARK: - Sign Out

  private var signOutButton: some View {
    LGButton("Sign Out", variant: .destructive) {
      store.send(.signOutTapped)
    }
  }

  // MARK: - Settings group helpers

  private func sectionLabel(_ title: String, accent: Color) -> some View {
    Text(title)
      .font(OMDFont.semibold(11))
      .foregroundStyle(accent)
      .textCase(.uppercase)
      .tracking(1.5)
  }

  private func settingsGroup(
    title: String,
    accent: Color,
    @ViewBuilder rows: () -> some View
  ) -> some View {
    VStack(alignment: .leading, spacing: Spacing.s200) {
      sectionLabel(title, accent: accent)

      VStack(spacing: 0) {
        rows()
      }
      .neonCard(accent: accent)
    }
  }

  private func settingRowButton(
    icon: String,
    label: String,
    accent: Color,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      SettingRowView(
        systemImage: icon,
        label: LocalizedStringKey(label),
        accessory: .chevron,
        accent: accent
      )
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
  }

  private var appVersion: String {
    let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    return "v\(version)"
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
        user: PreviewFixtures.user(.standard),
        metrics: PreviewFixtures.fileMetrics(.standard)
      )
    ) {
      ProfileFeature()
    }
  )
  .preferredColorScheme(.dark)
}
