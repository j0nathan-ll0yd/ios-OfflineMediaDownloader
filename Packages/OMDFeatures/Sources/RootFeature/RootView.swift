import ComposableArchitecture
import DesignSystem
import DiagnosticFeature
import LifegamesComponentsCore
import LifegamesTemplates
import LifegamesTokens
import MainFeature
import SwiftUI

// MARK: - RootView

public struct RootView: View {
  @Bindable var store: StoreOf<RootFeature>

  public init(store: StoreOf<RootFeature>) {
    self.store = store
  }

  public var body: some View {
    ZStack {
      // Always render MainView in background so it can start loading
      MainView(store: store.scope(state: \.main, action: \.main))

      if store.isLaunching {
        LaunchView()
          .transition(.opacity.animation(.easeInOut(duration: 0.5)))
          .zIndex(1)
      }
    }
    #if DEBUG
    .sheet(item: $store.scope(state: \.diagnostic, action: \.diagnostic)) { diagnosticStore in
        NavigationStack {
          DiagnosticView(store: diagnosticStore)
            .toolbar {
              ToolbarItem(placement: .topBarLeading) {
                Button("Done") {
                  store.send(.diagnostic(.dismiss))
                }
              }
            }
        }
      }
    #endif
  }
}

// MARK: - LaunchView (Pure SwiftUI - not TCA managed)

public struct LaunchView: View {
  public init() {}

  public var body: some View {
    // Pure Launch on AuthTemplate: no primaryAction / no footer. The OFFLINE
    // wordmark + buffering play-ring live in the branding slot; the OMD color
    // washes fill the template's background slot.
    AuthTemplate(
      title: nil,
      accent: OMDPalette.primary,
      branding: { branding },
      background: {
        ZStack {
          LinearGradient(
            colors: [LGColor.surfaceDeep, LGColor.surfaceBase],
            startPoint: .top,
            endPoint: .bottom
          )
          OMDBrand.colorWashes
        }
      }
    )
    .preferredColorScheme(.dark)
  }

  private var branding: some View {
    VStack(spacing: 0) {
      // Wordmark
      VStack(spacing: Spacing.s300) {
        Text("OFFLINE")
          .font(OMDFont.bold(54))
          .tracking(5)
          .foregroundStyle(OMDBrand.wordmarkGradient)
          .shadow(color: LGColor.accentCyan.opacity(0.5), radius: 18)
          .shadow(color: LGColor.accentPink.opacity(0.3), radius: 28)
          .minimumScaleFactor(0.6)
          .lineLimit(1)

        Text("media downloader")
          .font(OMDFont.medium(15))
          .tracking(5)
          .foregroundStyle(LGColor.accentCyan.opacity(0.9))
      }

      BufferRingAnimation()
        .frame(height: 200)
        .padding(.top, Spacing.s700)
    }
  }
}

// MARK: - DownloadInitiatingOverlay

public struct DownloadInitiatingOverlay: View {
  let title: String
  @State private var pulseScale: CGFloat = 1.0 // non-tca
  @State private var iconRotation: Double = 0 // non-tca

  private let theme = DarkProfessionalTheme()

  public init(title: String) {
    self.title = title
  }

  public var body: some View {
    ZStack {
      // Semi-transparent blocking background
      Color.black.opacity(0.85)
        .ignoresSafeArea()

      VStack(spacing: 24) {
        // Animated download icon
        ZStack {
          // Pulsing circle background
          Circle()
            .fill(
              LinearGradient(
                colors: [theme.primaryColor.opacity(0.3), theme.accentColor.opacity(0.2)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              )
            )
            .frame(width: 100, height: 100)
            .scaleEffect(pulseScale)

          // Download icon
          Image(systemName: "arrow.down.circle.fill")
            .font(.system(size: 48))
            .foregroundStyle(
              LinearGradient(
                colors: [theme.primaryColor, theme.accentColor],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              )
            )
            .rotationEffect(.degrees(iconRotation))
        }

        VStack(spacing: 12) {
          Text("Starting Download")
            .font(.title2)
            .fontWeight(.semibold)
            .foregroundStyle(theme.textPrimary)

          Text(title)
            .font(.subheadline)
            .foregroundStyle(theme.textSecondary)
            .lineLimit(2)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 280)

          // Progress spinner
          ProgressView()
            .progressViewStyle(CircularProgressViewStyle(tint: theme.primaryColor))
            .scaleEffect(1.2)
            .padding(.top, 8)

          Text("Please wait...")
            .font(.caption)
            .foregroundStyle(theme.textSecondary.opacity(0.7))
            .padding(.top, 4)
        }
      }
      .padding(32)
      .background(
        RoundedRectangle(cornerRadius: 24)
          .fill(theme.surfaceColor)
          .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
      )
    }
    .onAppear {
      withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
        pulseScale = 1.15
      }
      withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
        iconRotation = 10
      }
    }
    .preferredColorScheme(.dark)
  }
}

// MARK: - Preview

#Preview("Launch") {
  LaunchView()
    .preferredColorScheme(.dark)
}
