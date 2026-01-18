import SwiftUI
import ComposableArchitecture

struct DiagnosticView: View {
  @Bindable var store: StoreOf<DiagnosticFeature>

  private let theme = DarkProfessionalTheme()

  /// Extract user profile from keychain items
  /// The displayValue format is: "FirstName LastName (email@example.com)"
  private var userProfile: (name: String, email: String) {
    if let userData = store.keychainItems.first(where: { $0.itemType == .userData }) {
      let value = userData.displayValue
      // Parse format: "FirstName LastName (email@example.com)"
      if let emailStart = value.lastIndex(of: "("),
         let emailEnd = value.lastIndex(of: ")") {
        let name = String(value[..<emailStart]).trimmingCharacters(in: .whitespaces)
        let email = String(value[value.index(after: emailStart)..<emailEnd])
        return (name.isEmpty ? "User" : name, email.isEmpty ? "No email" : email)
      }
      // Fallback if format doesn't match
      return (value, "No email")
    }
    return ("User", "No email stored")
  }

  private var initials: String {
    let names = userProfile.name.split(separator: " ")
    let firstInitial = names.first?.prefix(1) ?? "U"
    let lastInitial = names.count > 1 ? names.last?.prefix(1) ?? "" : ""
    return "\(firstInitial)\(lastInitial)".uppercased()
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 24) {
          // Profile header
          profileHeader
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .padding(.horizontal, 16)

          // Stats cards (placeholder values)
          statsSection
            .padding(.horizontal, 16)

          // Settings sections
          VStack(spacing: 16) {
            settingsSection(title: "Account", items: [
              SettingsItem(icon: "person.crop.circle", title: "Edit Profile", color: theme.primaryColor),
              SettingsItem(icon: "bell", title: "Notifications", color: theme.warningColor),
            ])

            settingsSection(title: "Preferences", items: [
              SettingsItem(icon: "arrow.down.circle", title: "Download Quality", color: theme.primaryColor),
              SettingsItem(icon: "wifi", title: "Cellular Downloads", color: theme.successColor),
            ])

            settingsSection(title: "Support", items: [
              SettingsItem(icon: "questionmark.circle", title: "Help Center", color: theme.textSecondary),
              SettingsItem(icon: "star", title: "Rate App", color: theme.warningColor),
            ])

            #if DEBUG
            // Debug section
            debugSection
            #endif
          }
          .padding(.horizontal, 16)

          // Sign out button
          Button(action: { store.send(.signOutButtonTapped) }) {
            if store.isLoading {
              ProgressView()
                .tint(theme.errorColor)
            } else {
              Text("Sign Out")
                .font(.headline)
                .foregroundStyle(theme.errorColor)
            }
          }
          .frame(maxWidth: .infinity)
          .padding(.vertical, 14)
          .background(theme.errorColor.opacity(0.15))
          .clipShape(RoundedRectangle(cornerRadius: 12))
          .disabled(store.isLoading)
          .padding(.horizontal, 16)
          .padding(.top, 8)

          // Version info
          Text("Version 1.0.0 (Build 1)")
            .font(.caption)
            .foregroundStyle(theme.textSecondary)
            .padding(.bottom, 24)
        }
      }
      .background(theme.backgroundColor)
      .navigationTitle("Account")
      .navigationBarTitleDisplayMode(.large)
      .toolbarColorScheme(.dark, for: .navigationBar)
      .onAppear {
        store.send(.onAppear)
      }
      .alert($store.scope(state: \.alert, action: \.alert))
    }
    .preferredColorScheme(.dark)
  }

  // MARK: - Profile Header

  private var profileHeader: some View {
    VStack(spacing: 16) {
      // Avatar with gradient border
      ZStack {
        Circle()
          .stroke(
            LinearGradient(
              colors: [theme.primaryColor, theme.accentColor],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            ),
            lineWidth: 4
          )
          .frame(width: 104, height: 104)

        Circle()
          .fill(DarkProfessionalTheme.cardBackground)
          .frame(width: 96, height: 96)

        Text(initials)
          .font(.system(size: 36, weight: .semibold, design: .rounded))
          .foregroundStyle(theme.primaryColor)
      }

      VStack(spacing: 4) {
        Text(userProfile.name)
          .font(.title2)
          .fontWeight(.bold)
          .foregroundStyle(.white)

        Text(userProfile.email)
          .font(.subheadline)
          .foregroundStyle(theme.textSecondary)
      }
    }
    .padding(.vertical, 24)
    .frame(maxWidth: .infinity)
    .background(
      LinearGradient(
        colors: [theme.primaryColor.opacity(0.8), theme.accentColor.opacity(0.6)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
    )
  }

  // MARK: - Stats Section

  private var statsSection: some View {
    HStack(spacing: 12) {
      StatCard(
        title: "Downloads",
        value: "\(store.downloadCount)",
        icon: "arrow.down.circle.fill",
        gradient: [theme.primaryColor, theme.accentColor]
      )

      StatCard(
        title: "Storage",
        value: formattedStorageSize,
        icon: "internaldrive.fill",
        gradient: [theme.accentColor, Color(hex: "5AC8FA")]
      )

      StatCard(
        title: "Watched",
        value: "\(store.playCount)",
        icon: "play.circle.fill",
        gradient: [Color(hex: "5AC8FA"), theme.successColor]
      )
    }
  }

  private var formattedStorageSize: String {
    let bytes = store.totalStorageBytes
    if bytes == 0 {
      return "0 MB"
    } else if bytes < 1_000_000 {
      return String(format: "%.0f KB", Double(bytes) / 1_000)
    } else if bytes < 1_000_000_000 {
      return String(format: "%.1f MB", Double(bytes) / 1_000_000)
    } else {
      return String(format: "%.2f GB", Double(bytes) / 1_000_000_000)
    }
  }

  // MARK: - Settings Section

  private func settingsSection(title: String, items: [SettingsItem]) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title)
        .font(.caption)
        .fontWeight(.semibold)
        .foregroundStyle(theme.textSecondary)
        .textCase(.uppercase)
        .padding(.leading, 4)

      VStack(spacing: 0) {
        ForEach(items.indices, id: \.self) { index in
          settingsRow(item: items[index])

          if index < items.count - 1 {
            Divider()
              .background(DarkProfessionalTheme.divider)
              .padding(.leading, 52)
          }
        }
      }
      .background(DarkProfessionalTheme.cardBackground)
      .clipShape(RoundedRectangle(cornerRadius: 12))
    }
  }

  private func settingsRow(item: SettingsItem) -> some View {
    HStack(spacing: 12) {
      ZStack {
        RoundedRectangle(cornerRadius: 8)
          .fill(item.color.opacity(0.15))
          .frame(width: 36, height: 36)

        Image(systemName: item.icon)
          .font(.system(size: 16))
          .foregroundStyle(item.color)
      }

      Text(item.title)
        .font(.body)
        .foregroundStyle(.white)

      Spacer()

      Image(systemName: "chevron.right")
        .font(.system(size: 14, weight: .medium))
        .foregroundStyle(theme.textSecondary.opacity(0.5))
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
    .contentShape(Rectangle())
  }

  // MARK: - Debug Section

  #if DEBUG
  private var debugSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Developer")
        .font(.caption)
        .fontWeight(.semibold)
        .foregroundStyle(theme.textSecondary)
        .textCase(.uppercase)
        .padding(.leading, 4)

      VStack(spacing: 0) {
        // Loading indicator
        if store.isLoading {
          HStack {
            ProgressView()
              .tint(theme.primaryColor)
            Text("Loading...")
              .font(.subheadline)
              .foregroundStyle(theme.textSecondary)
          }
          .padding(16)
        }

        // Keychain items
        ForEach(Array(store.keychainItems.enumerated()), id: \.element.id) { index, item in
          NavigationLink(destination: KeychainDetailView(item: item) {
            store.send(.deleteKeychainItem(IndexSet(integer: index)))
          }) {
            keychainRow(item: item)
          }
          .buttonStyle(.plain)

          Divider()
            .background(DarkProfessionalTheme.divider)
            .padding(.leading, 52)
        }

        // Token expiration row
        tokenExpirationRow

        // Divider before Truncate button
        Divider()
          .background(DarkProfessionalTheme.divider)
          .padding(.leading, 52)

        // Truncate files button
        Button(action: { store.send(.truncateFilesButtonTapped) }) {
          HStack(spacing: 12) {
            ZStack {
              RoundedRectangle(cornerRadius: 8)
                .fill(theme.errorColor.opacity(0.15))
                .frame(width: 36, height: 36)

              Image(systemName: "trash")
                .font(.system(size: 16))
                .foregroundStyle(theme.errorColor)
            }

            Text("Truncate All Files")
              .font(.body)
              .foregroundStyle(theme.errorColor)

            Spacer()
          }
          .padding(.horizontal, 12)
          .padding(.vertical, 10)
        }
      }
      .background(DarkProfessionalTheme.cardBackground)
      .clipShape(RoundedRectangle(cornerRadius: 12))
    }
  }

  private func keychainRow(item: KeychainItem) -> some View {
    HStack(spacing: 12) {
      ZStack {
        RoundedRectangle(cornerRadius: 8)
          .fill(theme.primaryColor.opacity(0.15))
          .frame(width: 36, height: 36)

        Image(systemName: "key")
          .font(.system(size: 16))
          .foregroundStyle(theme.primaryColor)
      }

      VStack(alignment: .leading, spacing: 2) {
        Text(item.name)
          .font(.body)
          .foregroundStyle(.white)

        Text(item.displayValue.count > 30 ? String(item.displayValue.prefix(30)) + "..." : item.displayValue)
          .font(.caption)
          .foregroundStyle(theme.textSecondary)
          .lineLimit(1)
      }

      Spacer()

      Image(systemName: "chevron.right")
        .font(.system(size: 14, weight: .medium))
        .foregroundStyle(theme.textSecondary.opacity(0.5))
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
    .contentShape(Rectangle())
  }

  private var tokenExpirationRow: some View {
    HStack(spacing: 12) {
      ZStack {
        RoundedRectangle(cornerRadius: 8)
          .fill(theme.warningColor.opacity(0.15))
          .frame(width: 36, height: 36)

        Image(systemName: "clock")
          .font(.system(size: 16))
          .foregroundStyle(theme.warningColor)
      }

      VStack(alignment: .leading, spacing: 2) {
        Text("Token Expires")
          .font(.body)
          .foregroundStyle(.white)

        if let expiresAt = store.tokenExpiresAt {
          Text(formattedExpiration(expiresAt))
            .font(.caption)
            .foregroundStyle(expirationTextColor(expiresAt))
            .lineLimit(1)
        } else {
          Text("Not set")
            .font(.caption)
            .foregroundStyle(theme.textSecondary)
        }
      }

      Spacer()
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
  }

  private func formattedExpiration(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    let timeUntil = date.timeIntervalSinceNow
    if timeUntil < 0 {
      return "Expired: \(formatter.string(from: date))"
    } else if timeUntil < 300 {
      return "Expiring soon: \(formatter.string(from: date))"
    } else {
      return formatter.string(from: date)
    }
  }

  private func expirationTextColor(_ date: Date) -> Color {
    let timeUntil = date.timeIntervalSinceNow
    if timeUntil < 0 {
      return theme.errorColor
    } else if timeUntil < 300 {
      return theme.warningColor
    } else {
      return theme.successColor
    }
  }
  #endif
}

// MARK: - Supporting Types

private struct SettingsItem {
  let icon: String
  let title: String
  let color: Color
}

private struct StatCard: View {
  let title: String
  let value: String
  let icon: String
  let gradient: [Color]

  var body: some View {
    VStack(spacing: 8) {
      Image(systemName: icon)
        .font(.system(size: 24))
        .foregroundStyle(.white)

      Text(value)
        .font(.title3)
        .fontWeight(.bold)
        .foregroundStyle(.white)

      Text(title)
        .font(.caption2)
        .foregroundStyle(.white.opacity(0.8))
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 16)
    .background(
      LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
    )
    .clipShape(RoundedRectangle(cornerRadius: 16))
  }
}

struct KeychainDetailView: View {
  let item: KeychainItem
  var onDelete: (() -> Void)?

  private let theme = DarkProfessionalTheme()

  var body: some View {
    ZStack {
      theme.backgroundColor
        .ignoresSafeArea()

      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          // Header card
          VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
              ZStack {
                RoundedRectangle(cornerRadius: 10)
                  .fill(theme.primaryColor.opacity(0.15))
                  .frame(width: 44, height: 44)

                Image(systemName: "key.fill")
                  .font(.system(size: 20))
                  .foregroundStyle(theme.primaryColor)
              }

              VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                  .font(.headline)
                  .foregroundStyle(.white)

                Text(itemTypeName)
                  .font(.subheadline)
                  .foregroundStyle(theme.textSecondary)
              }
            }
          }
          .padding(16)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(DarkProfessionalTheme.cardBackground)
          .clipShape(RoundedRectangle(cornerRadius: 12))

          // Value section
          VStack(alignment: .leading, spacing: 8) {
            Text("VALUE")
              .font(.caption)
              .fontWeight(.semibold)
              .foregroundStyle(theme.textSecondary)

            Text(item.displayValue)
              .font(.system(.body, design: .monospaced))
              .foregroundStyle(.white)
              .textSelection(.enabled)
              .fixedSize(horizontal: false, vertical: true)
              .padding(16)
              .frame(maxWidth: .infinity, alignment: .leading)
              .background(DarkProfessionalTheme.cardBackground)
              .clipShape(RoundedRectangle(cornerRadius: 12))
          }

          // Delete button
          if let onDelete = onDelete {
            Button(action: onDelete) {
              HStack {
                Image(systemName: "trash")
                Text("Delete")
              }
              .font(.body)
              .fontWeight(.medium)
              .foregroundStyle(.white)
              .frame(maxWidth: .infinity)
              .padding(.vertical, 14)
              .background(theme.errorColor)
              .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.top, 8)
          }
        }
        .padding(16)
      }
    }
    .navigationTitle(item.name)
    .navigationBarTitleDisplayMode(.inline)
    .toolbarColorScheme(.dark, for: .navigationBar)
    .preferredColorScheme(.dark)
  }

  private var itemTypeName: String {
    switch item.itemType {
    case .token:
      return "JWT Token"
    case .userData:
      return "User Data"
    case .deviceData:
      return "Device Data"
    }
  }
}

#Preview {
  DiagnosticView(store: Store(initialState: DiagnosticFeature.State()) {
    DiagnosticFeature()
  })
}
