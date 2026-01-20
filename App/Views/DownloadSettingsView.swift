import SwiftUI
import ComposableArchitecture

struct DownloadSettingsView: View {
  @Bindable var store: StoreOf<DownloadSettingsFeature>

  private let theme = DarkProfessionalTheme()

  var body: some View {
    ZStack {
      theme.backgroundColor
        .ignoresSafeArea()

      ScrollView {
        VStack(spacing: 24) {
          // Header
          headerSection

          // Quality Selection
          qualitySection

          // Cellular Downloads Toggle
          cellularSection

          // Info note
          infoSection
        }
        .padding(16)
      }
    }
    .navigationTitle("Download Settings")
    .navigationBarTitleDisplayMode(.inline)
    .toolbarColorScheme(.dark, for: .navigationBar)
    .preferredColorScheme(.dark)
    .onAppear {
      store.send(.onAppear)
    }
  }

  // MARK: - Header Section

  private var headerSection: some View {
    VStack(spacing: 12) {
      ZStack {
        Circle()
          .fill(theme.primaryColor.opacity(0.15))
          .frame(width: 80, height: 80)

        Image(systemName: "arrow.down.circle.fill")
          .font(.system(size: 40))
          .foregroundStyle(theme.primaryColor)
      }

      Text("Download Preferences")
        .font(.title2)
        .fontWeight(.bold)
        .foregroundStyle(.white)

      Text("Configure how media files are downloaded")
        .font(.subheadline)
        .foregroundStyle(theme.textSecondary)
        .multilineTextAlignment(.center)
    }
    .padding(.top, 8)
  }

  // MARK: - Quality Section

  private var qualitySection: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("DOWNLOAD QUALITY")
        .font(.caption)
        .fontWeight(.semibold)
        .foregroundStyle(theme.textSecondary)
        .textCase(.uppercase)
        .padding(.leading, 4)

      VStack(spacing: 0) {
        ForEach(DownloadQuality.allCases, id: \.self) { quality in
          qualityRow(quality)

          if quality != DownloadQuality.allCases.last {
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

  private func qualityRow(_ quality: DownloadQuality) -> some View {
    Button(action: { store.send(.qualitySelected(quality)) }) {
      HStack(spacing: 12) {
        ZStack {
          RoundedRectangle(cornerRadius: 8)
            .fill(iconColor(for: quality).opacity(0.15))
            .frame(width: 36, height: 36)

          Image(systemName: iconName(for: quality))
            .font(.system(size: 16))
            .foregroundStyle(iconColor(for: quality))
        }

        VStack(alignment: .leading, spacing: 2) {
          Text(quality.displayName)
            .font(.body)
            .foregroundStyle(.white)

          Text(quality.description)
            .font(.caption)
            .foregroundStyle(theme.textSecondary)
            .lineLimit(1)
        }

        Spacer()

        if store.downloadQuality == quality {
          Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 22))
            .foregroundStyle(theme.primaryColor)
        } else {
          Image(systemName: "circle")
            .font(.system(size: 22))
            .foregroundStyle(theme.textSecondary.opacity(0.5))
        }
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 12)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }

  private func iconName(for quality: DownloadQuality) -> String {
    switch quality {
    case .auto:
      return "sparkles"
    case .high:
      return "4k.tv"
    case .medium:
      return "film"
    case .low:
      return "antenna.radiowaves.left.and.right"
    }
  }

  private func iconColor(for quality: DownloadQuality) -> Color {
    switch quality {
    case .auto:
      return theme.primaryColor
    case .high:
      return theme.accentColor
    case .medium:
      return theme.warningColor
    case .low:
      return theme.successColor
    }
  }

  // MARK: - Cellular Section

  private var cellularSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("NETWORK")
        .font(.caption)
        .fontWeight(.semibold)
        .foregroundStyle(theme.textSecondary)
        .textCase(.uppercase)
        .padding(.leading, 4)

      HStack(spacing: 12) {
        ZStack {
          RoundedRectangle(cornerRadius: 8)
            .fill(theme.successColor.opacity(0.15))
            .frame(width: 36, height: 36)

          Image(systemName: "antenna.radiowaves.left.and.right")
            .font(.system(size: 16))
            .foregroundStyle(theme.successColor)
        }

        VStack(alignment: .leading, spacing: 2) {
          Text("Cellular Downloads")
            .font(.body)
            .foregroundStyle(.white)

          Text("Download files using mobile data")
            .font(.caption)
            .foregroundStyle(theme.textSecondary)
        }

        Spacer()

        Toggle("", isOn: Binding(
          get: { store.cellularDownloadsEnabled },
          set: { store.send(.cellularToggled($0)) }
        ))
        .labelsHidden()
        .tint(theme.primaryColor)
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 12)
      .background(DarkProfessionalTheme.cardBackground)
      .clipShape(RoundedRectangle(cornerRadius: 12))
    }
  }

  // MARK: - Info Section

  private var infoSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 8) {
        Image(systemName: "info.circle")
          .font(.system(size: 14))
          .foregroundStyle(theme.textSecondary)

        Text("Note")
          .font(.caption)
          .fontWeight(.semibold)
          .foregroundStyle(theme.textSecondary)
      }

      Text("Quality selection will be applied to future downloads when the backend supports multiple quality options. Current downloads use the available quality from the server.")
        .font(.caption)
        .foregroundStyle(theme.textSecondary)
        .padding(12)
        .background(theme.backgroundColor.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    .padding(.top, 8)
  }
}

#Preview {
  NavigationStack {
    DownloadSettingsView(store: Store(initialState: DownloadSettingsFeature.State()) {
      DownloadSettingsFeature()
    })
  }
}
