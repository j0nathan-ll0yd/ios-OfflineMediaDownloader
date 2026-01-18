import SwiftUI
import ComposableArchitecture
import UserNotifications

// MARK: - Shake Gesture Detection

#if DEBUG
extension NSNotification.Name {
  static let deviceDidShake = NSNotification.Name("DeviceDidShakeNotification")
}

extension UIWindow {
  open override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
    super.motionEnded(motion, with: event)
    if motion == .motionShake {
      NotificationCenter.default.post(name: .deviceDidShake, object: nil)
    }
  }
}

struct ShakeDetectorModifier: ViewModifier {
  let onShake: () -> Void

  func body(content: Content) -> some View {
    content
      .onReceive(NotificationCenter.default.publisher(for: .deviceDidShake)) { _ in
        onShake()
      }
  }
}

extension View {
  func onShake(perform action: @escaping () -> Void) -> some View {
    modifier(ShakeDetectorModifier(onShake: action))
  }
}
#endif

// MARK: - RootView
// Feature: App/Features/RootFeature.swift

struct RootView: View {
  @Bindable var store: StoreOf<RootFeature>

  init(store: StoreOf<RootFeature>) {
    self.store = store
  }

  var body: some View {
    Group {
      if store.isLaunching {
        LaunchView(status: store.launchStatus)
      } else {
        // Always show MainView - auth state is handled within MainFeature
        MainView(store: store.scope(state: \.main, action: \.main))
      }
    }
    .overlay {
      // Blocking overlay while waiting for download to start
      if store.isBlockingForDownloadInitiation,
         let initiation = store.initiatingDownloads.first {
        DownloadInitiatingOverlay(title: initiation.title)
          .transition(.opacity)
          .animation(.easeInOut(duration: 0.3), value: store.isBlockingForDownloadInitiation)
      }
    }
    #if DEBUG
    .onShake {
      store.send(.shakeDetected)
    }
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

// MARK: - Launch View (Pure SwiftUI - not TCA managed)
struct LaunchView: View {
  let status: String
  @State private var dotOffset: CGFloat = 0  // non-tca
  @State private var showShapes = false  // non-tca

  private let theme = DarkProfessionalTheme()

  var body: some View {
    ZStack {
      // Dark background
      theme.backgroundColor
        .ignoresSafeArea()

      // Floating geometric shapes
      GeometryReader { geometry in
        ZStack {
          // Blue circle
          Circle()
            .fill(theme.primaryColor.opacity(0.25))
            .frame(width: 200, height: 200)
            .blur(radius: 40)
            .offset(x: showShapes ? -50 : -80, y: -150)
            .animation(.easeInOut(duration: 3).repeatForever(autoreverses: true), value: showShapes)

          // Purple circle
          Circle()
            .fill(theme.accentColor.opacity(0.2))
            .frame(width: 180, height: 180)
            .blur(radius: 35)
            .offset(x: showShapes ? 100 : 130, y: 50)
            .animation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true), value: showShapes)

          // Teal circle
          Circle()
            .fill(Color(hex: "5AC8FA").opacity(0.15))
            .frame(width: 150, height: 150)
            .blur(radius: 30)
            .offset(x: showShapes ? -80 : -50, y: 200)
            .animation(.easeInOut(duration: 3.5).repeatForever(autoreverses: true), value: showShapes)
        }
        .frame(width: geometry.size.width, height: geometry.size.height)
      }
      .ignoresSafeArea()

      VStack(spacing: 40) {
        Spacer()

        // Logo
        LifegamesLogo(size: .large, animated: true)

        Spacer()

        // Animated loading dots
        VStack(spacing: 20) {
          HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { index in
              Circle()
                .fill(
                  LinearGradient(
                    colors: [theme.primaryColor, theme.accentColor],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                  )
                )
                .frame(width: 12, height: 12)
                .offset(y: dotOffset)
                .animation(
                  .easeInOut(duration: 0.4)
                    .repeatForever(autoreverses: true)
                    .delay(Double(index) * 0.15),
                  value: dotOffset
                )
            }
          }

          Text(status)
            .font(.subheadline)
            .foregroundStyle(theme.textSecondary)
        }
        .padding(.bottom, 60)
      }
    }
    .preferredColorScheme(.dark)
    .onAppear {
      showShapes = true
      dotOffset = -10
    }
  }
}

#Preview {
  RootView(store: Store(initialState: RootFeature.State()) {
    RootFeature()
  })
}
