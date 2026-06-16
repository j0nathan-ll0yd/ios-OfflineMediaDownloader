import ComposableArchitecture
import DesignSystem
import LifegamesTemplates
import LifegamesTokens
import SwiftUI

/// DownloadSettings migrated onto the Lifegames `SettingsTemplate`.
///
/// The download-quality picker does NOT fit `SettingsTemplate`'s closed row
/// taxonomy (navigation / toggle / value / destructive) — its radio-card UI
/// (selection ring, glow, checkmark) is rendered as a HOST sibling section
/// ABOVE the template. The cellular toggle DOES fit, so it lives inside
/// `SettingsTemplate`; the storage/quality help copy is the section footer.
///
/// `SettingsTemplate` renders its own `List`, so it is given a bounded height
/// and `.scrollDisabled(true)` to stack cleanly under the host `ScrollView`
/// (mirrors the gallery DownloadSettings layout).
public struct DownloadSettingsView: View {
  @Bindable var store: StoreOf<DownloadSettingsFeature>

  public init(store: StoreOf<DownloadSettingsFeature>) {
    self.store = store
  }

  public var body: some View {
    ScrollView {
      VStack(spacing: Spacing.s500) {
        qualitySection
        cellularSettings
      }
      .padding(Spacing.s400)
    }
    .background(LGColor.surfaceBase.ignoresSafeArea())
    .navigationTitle("Download Settings")
    #if os(iOS)
      .navigationBarTitleDisplayMode(.inline)
      .toolbarColorScheme(.dark, for: .navigationBar)
    #endif
      .preferredColorScheme(.dark)
      .task { store.send(.onAppear) }
  }

  // MARK: - Quality Section (host sibling — radio cards)

  private var qualitySection: some View {
    VStack(alignment: .leading, spacing: Spacing.s300) {
      Text("Quality")
        .font(OMDFont.semibold(11))
        .foregroundStyle(OMDPalette.playback)
        .textCase(.uppercase)
        .tracking(1.5)

      VStack(spacing: Spacing.s300) {
        ForEach(DownloadQuality.allCases, id: \.self) { quality in
          qualityCard(quality, isSelected: store.downloadQuality == quality)
        }
      }
    }
  }

  private func qualityCard(_ quality: DownloadQuality, isSelected: Bool) -> some View {
    Button(action: { store.send(.qualitySelected(quality)) }) {
      HStack(spacing: Spacing.s400) {
        ZStack {
          Circle()
            .stroke(
              isSelected ? OMDPalette.playback : LGColor.borderSubtle,
              lineWidth: isSelected ? 2 : 1
            )
            .frame(width: 20, height: 20)
          if isSelected {
            Circle()
              .fill(OMDPalette.playback)
              .frame(width: 10, height: 10)
              .shadow(color: OMDPalette.playback.opacity(0.8), radius: 4)
          }
        }

        VStack(alignment: .leading, spacing: 2) {
          Text(quality.displayName)
            .font(isSelected ? OMDFont.semibold(15) : OMDFont.regular(15))
            .foregroundStyle(isSelected ? LGColor.textTitle : LGColor.textMuted)

          Text(quality.qualityDescription)
            .font(OMDFont.regular(11))
            .foregroundStyle(LGColor.textSubtle)
            .lineLimit(2)
        }

        Spacer(minLength: Spacing.s300)

        if isSelected {
          Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 18))
            .foregroundStyle(OMDPalette.playback)
            .shadow(color: OMDPalette.playback.opacity(0.6), radius: 6)
        }
      }
      .padding(Spacing.s450)
      .frame(minHeight: 44)
      .background(
        isSelected
          ? OMDPalette.playback.opacity(0.08)
          : LGColor.surfaceRaised.opacity(0.6)
      )
      .overlay(
        RoundedRectangle(cornerRadius: 16)
          .stroke(
            isSelected ? OMDPalette.playback.opacity(0.6) : LGColor.borderSubtle,
            lineWidth: isSelected ? 1.5 : 1
          )
      )
      .clipShape(RoundedRectangle(cornerRadius: 16))
      .shadow(
        color: isSelected ? OMDPalette.playback.opacity(0.2) : .clear,
        radius: isSelected ? 10 : 0
      )
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .accessibilityLabel(quality.displayName)
    .accessibilityValue(isSelected ? "Selected" : "Not selected")
  }

  // MARK: - Cellular Section (SettingsTemplate)

  private var cellularSettings: some View {
    SettingsTemplate(
      sections: [
        SettingsTemplate.Section(
          title: "Network",
          footer: "Higher quality requires more storage space and longer download times. Files already downloaded are not affected by quality changes.",
          rows: [
            .toggle(
              label: "Cellular Downloads",
              systemImage: "antenna.radiowaves.left.and.right",
              isOn: Binding(
                get: { store.cellularDownloadsEnabled },
                set: { store.send(.cellularToggled($0)) }
              )
            ),
          ]
        ),
      ],
      accent: OMDPalette.playback
    )
    .frame(height: 200)
    .scrollDisabled(true)
  }
}

#Preview {
  NavigationStack {
    DownloadSettingsView(store: Store(initialState: DownloadSettingsFeature.State()) {
      DownloadSettingsFeature()
    })
  }
  .preferredColorScheme(.dark)
}
