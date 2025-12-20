import SwiftUI

// MARK: - Lifegames Pro - Account View

struct LifegamesAccountView: View {
    var profile: UserProfile = .placeholder
    var keychainItems: [LifegamesKeychainItem] = LifegamesKeychainItem.samples
    @State private var showDebug = false

    private let theme = DarkProfessionalTheme()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Profile header
                    darkGradientProfileHeader
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .padding(.horizontal, 16)

                    // Stats cards
                    statsSection
                        .padding(.horizontal, 16)

                    // Settings sections
                    VStack(spacing: 16) {
                        settingsSection(title: "Account", items: [
                            LifegamesSettingsItem(icon: "person.crop.circle", title: "Edit Profile", color: theme.primaryColor),
                            LifegamesSettingsItem(icon: "creditcard", title: "Subscription", color: theme.accentColor),
                            LifegamesSettingsItem(icon: "bell", title: "Notifications", color: theme.warningColor),
                        ])

                        settingsSection(title: "Preferences", items: [
                            LifegamesSettingsItem(icon: "arrow.down.circle", title: "Download Quality", color: theme.primaryColor),
                            LifegamesSettingsItem(icon: "wifi", title: "Cellular Downloads", color: theme.successColor),
                            LifegamesSettingsItem(icon: "moon", title: "Appearance", color: theme.accentColor),
                        ])

                        settingsSection(title: "Support", items: [
                            LifegamesSettingsItem(icon: "questionmark.circle", title: "Help Center", color: theme.textSecondary),
                            LifegamesSettingsItem(icon: "envelope", title: "Contact Us", color: theme.textSecondary),
                            LifegamesSettingsItem(icon: "star", title: "Rate App", color: theme.warningColor),
                        ])

                        #if DEBUG
                        // Debug section (only in debug builds)
                        debugSection
                        #endif
                    }
                    .padding(.horizontal, 16)

                    // Sign out button
                    Button(action: { }) {
                        Text("Sign Out")
                            .font(.headline)
                            .foregroundStyle(theme.errorColor)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(theme.errorColor.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
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
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Dark Gradient Profile Header

    private var darkGradientProfileHeader: some View {
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

                // Avatar placeholder with initials
                Circle()
                    .fill(DarkProfessionalTheme.cardBackground)
                    .frame(width: 96, height: 96)

                Text(initials)
                    .font(.system(size: 36, weight: .semibold, design: .rounded))
                    .foregroundStyle(theme.primaryColor)
            }

            VStack(spacing: 4) {
                Text(profile.name)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)

                Text(profile.email)
                    .font(.subheadline)
                    .foregroundStyle(theme.textSecondary)
            }

            Button(action: { }) {
                HStack(spacing: 6) {
                    Image(systemName: "pencil")
                        .font(.system(size: 14))
                    Text("Edit Profile")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.15))
                .clipShape(Capsule())
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

    private var initials: String {
        let names = profile.name.split(separator: " ")
        let firstInitial = names.first?.prefix(1) ?? ""
        let lastInitial = names.count > 1 ? names.last?.prefix(1) ?? "" : ""
        return "\(firstInitial)\(lastInitial)".uppercased()
    }

    // MARK: - Stats Section

    private var statsSection: some View {
        HStack(spacing: 12) {
            LifegamesStatCard(
                title: "Downloads",
                value: "12",
                icon: "arrow.down.circle.fill",
                gradient: [theme.primaryColor, theme.accentColor]
            )

            LifegamesStatCard(
                title: "Storage",
                value: "2.4 GB",
                icon: "internaldrive.fill",
                gradient: [theme.accentColor, Color(hex: "5AC8FA")]
            )

            LifegamesStatCard(
                title: "Watched",
                value: "8",
                icon: "play.circle.fill",
                gradient: [Color(hex: "5AC8FA"), theme.successColor]
            )
        }
    }

    // MARK: - Settings Section

    private func settingsSection(title: String, items: [LifegamesSettingsItem]) -> some View {
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

    private func settingsRow(item: LifegamesSettingsItem) -> some View {
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
            Button(action: { withAnimation { showDebug.toggle() } }) {
                HStack {
                    Text("Developer")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(theme.textSecondary)
                        .textCase(.uppercase)

                    Spacer()

                    Image(systemName: showDebug ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(theme.textSecondary)
                }
                .padding(.leading, 4)
            }

            if showDebug {
                VStack(spacing: 0) {
                    // Keychain items
                    ForEach(keychainItems) { item in
                        keychainRow(item: item)
                        Divider()
                            .background(DarkProfessionalTheme.divider)
                            .padding(.leading, 52)
                    }

                    // Destructive actions
                    Button(action: { }) {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(theme.errorColor.opacity(0.15))
                                    .frame(width: 36, height: 36)

                                Image(systemName: "trash")
                                    .font(.system(size: 16))
                                    .foregroundStyle(theme.errorColor)
                            }

                            Text("Clear All Data")
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
    }

    private func keychainRow(item: LifegamesKeychainItem) -> some View {
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

                Text(item.truncatedValue)
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
    #endif
}

// MARK: - Settings Item Model

private struct LifegamesSettingsItem {
    let icon: String
    let title: String
    let color: Color
}

// MARK: - Stat Card

private struct LifegamesStatCard: View {
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

// MARK: - Keychain Item Model

struct LifegamesKeychainItem: Identifiable {
    let id: String
    let name: String
    let value: String

    var truncatedValue: String {
        if value.count > 30 {
            return String(value.prefix(30)) + "..."
        }
        return value
    }

    static let samples: [LifegamesKeychainItem] = [
        LifegamesKeychainItem(id: "1", name: "Authentication Token", value: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0"),
        LifegamesKeychainItem(id: "2", name: "User Data", value: "{\"name\":\"John\",\"email\":\"john@example.com\"}"),
        LifegamesKeychainItem(id: "3", name: "Device ID", value: "A1B2C3D4-E5F6-7890-ABCD-EF1234567890"),
    ]
}

// MARK: - Previews

#Preview("Account - Default") {
    LifegamesAccountView()
}

#Preview("Account - With User") {
    LifegamesAccountView(
        profile: UserProfile(
            name: "Jane Doe",
            email: "jane@lifegames.com",
            avatarURL: nil
        )
    )
}
