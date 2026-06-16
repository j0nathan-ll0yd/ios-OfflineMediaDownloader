import ComposableArchitecture
import DesignSystem
import LifegamesComponents
import LifegamesTokens
import SharedModels
import SwiftUI

// MARK: - DiagnosticView

/// Focused diagnostics screen used by the DEBUG shake-to-debug sheet
/// (`RootFeature`). It renders ONLY the developer tools via the reusable
/// `DiagnosticSection` — no profile header, stats, or settings chrome (those
/// live on the Account screen, which embeds `DiagnosticSection` inline). The
/// host (`RootView`) owns the `NavigationStack`.
public struct DiagnosticView: View {
  @Bindable var store: StoreOf<DiagnosticFeature>

  public init(store: StoreOf<DiagnosticFeature>) {
    self.store = store
  }

  public var body: some View {
    ScrollView {
      DiagnosticSection(store: store)
        .padding(Spacing.s400)
    }
    .background(LGColor.surfaceBase)
    .navigationTitle("Diagnostics")
    #if os(iOS)
      .navigationBarTitleDisplayMode(.large)
      .toolbarColorScheme(.dark, for: .navigationBar)
    #endif
      .preferredColorScheme(.dark)
  }
}

// MARK: - DiagnosticSection

/// Reusable developer-tools block: keychain inspector, token-expiration debug
/// controls, file truncation, and build version. Rendered inline within the
/// Account screen (`ProfileView`) and standalone inside `DiagnosticView`.
/// Drill-downs (`KeychainDetailView`, `TokenExpirationDetailView`) push onto
/// the host's `NavigationStack`.
public struct DiagnosticSection: View {
  @Bindable var store: StoreOf<DiagnosticFeature>

  public init(store: StoreOf<DiagnosticFeature>) {
    self.store = store
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: Spacing.s300) {
      Text("Diagnostics")
        .font(OMDFont.bold(12))
        .foregroundStyle(OMDPalette.content)
        .textCase(.uppercase)
        .shadow(color: OMDPalette.content.opacity(0.4), radius: 3)
        .padding(.leading, Spacing.s100)

      VStack(spacing: 0) {
        if store.isLoading {
          HStack(spacing: Spacing.s300) {
            ProgressView()
              .tint(OMDPalette.primary)
            Text("Loading…")
              .font(OMDFont.regular(13))
              .foregroundStyle(LGColor.textSubtle)
            Spacer()
          }
          .padding(Spacing.s400)
        }

        ForEach(Array(store.keychainItems.enumerated()), id: \.element.id) { index, item in
          NavigationLink {
            KeychainDetailView(item: item) {
              store.send(.deleteKeychainItem(IndexSet(integer: index)))
            }
          } label: {
            keychainRow(item: item)
          }
          .buttonStyle(.plain)

          rowDivider
        }

        NavigationLink {
          TokenExpirationDetailView(
            expiresAt: store.tokenExpiresAt,
            onDelete: { store.send(.deleteTokenExpiration) },
            onExpireSoon: { store.send(.setTokenExpiringSoon) }
          )
        } label: {
          tokenExpirationRow
        }
        .buttonStyle(.plain)

        rowDivider

        Button {
          store.send(.truncateFilesButtonTapped)
        } label: {
          iconRow(
            systemImage: "trash",
            title: "Truncate All Files",
            accent: OMDPalette.destructive,
            titleColor: OMDPalette.destructive
          )
        }
        .buttonStyle(.plain)
      }
      .background(LGColor.surfaceRaised)
      .clipShape(RoundedRectangle(cornerRadius: 12))

      Text("Version 1.0.0 (Build 1)")
        .font(OMDFont.mono(11))
        .foregroundStyle(LGColor.textSubtle)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, Spacing.s200)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .alert($store.scope(state: \.alert, action: \.alert))
    .task { store.send(.onAppear) }
  }

  // MARK: - Rows

  private var rowDivider: some View {
    Rectangle()
      .fill(LGColor.borderSubtle)
      .frame(height: 0.5)
      .padding(.leading, 52)
  }

  private func iconTile(systemImage: String, accent: Color) -> some View {
    RoundedRectangle(cornerRadius: 8)
      .fill(accent.opacity(0.15))
      .frame(width: 36, height: 36)
      .overlay(
        Image(systemName: systemImage)
          .font(.system(size: 16))
          .foregroundStyle(accent)
      )
  }

  private func iconRow(systemImage: String, title: String, accent: Color, titleColor: Color) -> some View {
    HStack(spacing: Spacing.s300) {
      iconTile(systemImage: systemImage, accent: accent)

      Text(title)
        .font(OMDFont.regular(15))
        .foregroundStyle(titleColor)

      Spacer()
    }
    .padding(.horizontal, Spacing.s300)
    .padding(.vertical, Spacing.s250)
    .contentShape(.rect)
  }

  private func keychainRow(item: KeychainItem) -> some View {
    HStack(spacing: Spacing.s300) {
      iconTile(systemImage: "key", accent: OMDPalette.primary)

      VStack(alignment: .leading, spacing: 2) {
        Text(item.name)
          .font(OMDFont.regular(15))
          .foregroundStyle(LGColor.textTitle)

        Text(item.displayValue.count > 30 ? String(item.displayValue.prefix(30)) + "…" : item.displayValue)
          .font(OMDFont.mono(11))
          .foregroundStyle(LGColor.textSubtle)
          .lineLimit(1)
      }

      Spacer()

      chevron
    }
    .padding(.horizontal, Spacing.s300)
    .padding(.vertical, Spacing.s250)
    .contentShape(.rect)
  }

  private var tokenExpirationRow: some View {
    HStack(spacing: Spacing.s300) {
      iconTile(systemImage: "clock", accent: OMDPalette.queued)

      VStack(alignment: .leading, spacing: 2) {
        Text("Token Expires")
          .font(OMDFont.regular(15))
          .foregroundStyle(LGColor.textTitle)

        if let expiresAt = store.tokenExpiresAt {
          Text(formattedExpiration(expiresAt))
            .font(OMDFont.mono(11))
            .foregroundStyle(expirationTextColor(expiresAt))
            .lineLimit(1)
        } else {
          Text("Not set")
            .font(OMDFont.mono(11))
            .foregroundStyle(LGColor.textSubtle)
        }
      }

      Spacer()

      chevron
    }
    .padding(.horizontal, Spacing.s300)
    .padding(.vertical, Spacing.s250)
    .contentShape(.rect)
  }

  private var chevron: some View {
    Image(systemName: "chevron.right")
      .font(.system(size: 14, weight: .medium))
      .foregroundStyle(LGColor.textSubtle.opacity(0.6))
  }

  // MARK: - Formatters

  private static let expirationFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter
  }()

  private func formattedExpiration(_ date: Date) -> String {
    let timeUntil = date.timeIntervalSinceNow
    if timeUntil < 0 {
      return "Expired: \(Self.expirationFormatter.string(from: date))"
    } else if timeUntil < 300 {
      return "Expiring soon: \(Self.expirationFormatter.string(from: date))"
    } else {
      return Self.expirationFormatter.string(from: date)
    }
  }

  private func expirationTextColor(_ date: Date) -> Color {
    let timeUntil = date.timeIntervalSinceNow
    if timeUntil < 0 {
      return OMDPalette.destructive
    } else if timeUntil < 300 {
      return OMDPalette.queued
    } else {
      return OMDPalette.complete
    }
  }
}

// MARK: - KeychainDetailView

public struct KeychainDetailView: View {
  let item: KeychainItem
  var onDelete: (() -> Void)?

  private let theme = DarkProfessionalTheme()

  public init(item: KeychainItem, onDelete: (() -> Void)? = nil) {
    self.item = item
    self.onDelete = onDelete
  }

  public var body: some View {
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
          if let onDelete {
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
      "JWT Token"
    case .userData:
      "User Data"
    case .deviceData:
      "Device Data"
    }
  }
}

// MARK: - TokenExpirationDetailView

public struct TokenExpirationDetailView: View {
  let expiresAt: Date?
  var onDelete: (() -> Void)?
  var onExpireSoon: (() -> Void)?

  @SwiftUI.Environment(\.dismiss) private var dismiss
  private let theme = DarkProfessionalTheme()

  public init(expiresAt: Date?, onDelete: (() -> Void)? = nil, onExpireSoon: (() -> Void)? = nil) {
    self.expiresAt = expiresAt
    self.onDelete = onDelete
    self.onExpireSoon = onExpireSoon
  }

  public var body: some View {
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
                  .fill(theme.warningColor.opacity(0.15))
                  .frame(width: 44, height: 44)

                Image(systemName: "clock.fill")
                  .font(.system(size: 20))
                  .foregroundStyle(theme.warningColor)
              }

              VStack(alignment: .leading, spacing: 2) {
                Text("Token Expiration")
                  .font(.headline)
                  .foregroundStyle(.white)

                Text("Debug Controls")
                  .font(.subheadline)
                  .foregroundStyle(theme.textSecondary)
              }
            }
          }
          .padding(16)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(DarkProfessionalTheme.cardBackground)
          .clipShape(RoundedRectangle(cornerRadius: 12))

          // Current value section
          VStack(alignment: .leading, spacing: 8) {
            Text("CURRENT VALUE")
              .font(.caption)
              .fontWeight(.semibold)
              .foregroundStyle(theme.textSecondary)

            Text(formattedValue)
              .font(.system(.body, design: .monospaced))
              .foregroundStyle(statusColor)
              .textSelection(.enabled)
              .fixedSize(horizontal: false, vertical: true)
              .padding(16)
              .frame(maxWidth: .infinity, alignment: .leading)
              .background(DarkProfessionalTheme.cardBackground)
              .clipShape(RoundedRectangle(cornerRadius: 12))
          }

          // Action buttons
          VStack(spacing: 12) {
            // Expire Soon button
            if let onExpireSoon {
              Button(action: {
                onExpireSoon()
                dismiss()
              }) {
                HStack {
                  Image(systemName: "clock.badge.exclamationmark")
                  Text("Set Expiring Soon (2 min)")
                }
                .font(.body)
                .fontWeight(.medium)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(theme.warningColor)
                .clipShape(RoundedRectangle(cornerRadius: 12))
              }
            }

            // Delete button
            if let onDelete, expiresAt != nil {
              Button(action: {
                onDelete()
                dismiss()
              }) {
                HStack {
                  Image(systemName: "trash")
                  Text("Delete Expiration")
                }
                .font(.body)
                .fontWeight(.medium)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(theme.errorColor)
                .clipShape(RoundedRectangle(cornerRadius: 12))
              }
            }
          }
          .padding(.top, 8)

          // Instructions
          VStack(alignment: .leading, spacing: 8) {
            Text("TESTING INSTRUCTIONS")
              .font(.caption)
              .fontWeight(.semibold)
              .foregroundStyle(theme.textSecondary)

            Text(
              "1. Tap \"Set Expiring Soon\" to set expiration to 2 minutes from now\n2. Close the app completely (swipe up from app switcher)\n3. Relaunch the app\n4. The app will detect the token expires within 5 minutes and automatically refresh it"
            )
            .font(.caption)
            .foregroundStyle(theme.textSecondary)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DarkProfessionalTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
          }
          .padding(.top, 8)
        }
        .padding(16)
      }
    }
    .navigationTitle("Token Expiration")
    .navigationBarTitleDisplayMode(.inline)
    .toolbarColorScheme(.dark, for: .navigationBar)
    .preferredColorScheme(.dark)
  }

  private static let dateTimeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .medium
    return formatter
  }()

  private var formattedValue: String {
    guard let expiresAt else {
      return "Not set"
    }
    return Self.dateTimeFormatter.string(from: expiresAt)
  }

  private var statusColor: Color {
    guard let expiresAt else {
      return theme.textSecondary
    }
    let timeUntil = expiresAt.timeIntervalSinceNow
    if timeUntil < 0 {
      return theme.errorColor
    } else if timeUntil < 300 {
      return theme.warningColor
    } else {
      return theme.successColor
    }
  }
}
