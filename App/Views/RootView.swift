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

func setupNotifications() {
  let center = UNUserNotificationCenter.current()
  center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
    guard granted else { return }
    UNUserNotificationCenter.current().getNotificationSettings { settings in
      guard settings.authorizationStatus == .authorized else { return }
      DispatchQueue.main.async {
        UIApplication.shared.registerForRemoteNotifications()
      }
    }
  }
}

@Reducer
struct RootFeature {
  init() {}

  @ObservableState
  struct State: Equatable {
    init() {}
    var isLaunching: Bool = true
    var launchStatus: String = "Starting..."
    var isAuthenticated: Bool = false
    var login: LoginFeature.State = LoginFeature.State()
    var main: MainFeature.State = MainFeature.State()
    #if DEBUG
    @Presents var diagnostic: DiagnosticFeature.State?
    #endif
  }

  enum Action {
    case didFinishLaunching
    case authStateResponse(AuthState)
    case didRegisterForRemoteNotificationsWithDeviceToken(String)
    case didFailToRegisterForRemoteNotificationsWithError(Error)
    case deviceRegistrationResponse(Result<RegisterDeviceResponse, Error>)
    // Push notification actions
    case receivedPushNotification([AnyHashable: Any])
    case processedPushNotification(PushNotificationType)
    case fileMetadataSaved(File)
    case downloadReadyProcessed(fileId: String, key: String, url: URL, size: Int64)
    case backgroundDownloadCompleted(fileId: String)
    case backgroundDownloadFailed(fileId: String, error: String)
    case login(LoginFeature.Action)
    case main(MainFeature.Action)
    #if DEBUG
    case shakeDetected
    case diagnostic(PresentationAction<DiagnosticFeature.Action>)
    #endif
  }

  @Dependency(\.authenticationClient) var authenticationClient
  @Dependency(\.serverClient) var serverClient
  @Dependency(\.keychainClient) var keychainClient
  @Dependency(\.coreDataClient) var coreDataClient
  @Dependency(\.downloadClient) var downloadClient
  @Dependency(\.fileClient) var fileClient
  @Dependency(\.logger) var logger

  var body: some ReducerOf<Self> {
    Scope(state: \.login, action: \.login) {
      LoginFeature()
    }

    Reduce { state, action in
      switch action {
      case .didFinishLaunching:
        // Keep isLaunching = true until auth check completes
        state.launchStatus = "Checking authentication..."
        logger.info(.lifecycle, "App launched - checking authentication status")
        setupNotifications()
        return .run { [authenticationClient] send in
          let authState = await authenticationClient.determineAuthState()
          await send(.authStateResponse(authState))
        }

      case let .authStateResponse(authState):
        logger.info(.lifecycle, "Auth state determined", metadata: [
          "loginStatus": "\(authState.loginStatus)",
          "registrationStatus": "\(authState.registrationStatus)"
        ])
        state.isLaunching = false  // Now safe to show main view
        state.login.registrationStatus = authState.registrationStatus
        state.isAuthenticated = authState.isAuthenticated
        // Propagate auth state to MainFeature
        state.main.isAuthenticated = authState.isAuthenticated
        state.main.fileList.isAuthenticated = authState.isAuthenticated

        if authState.isAuthenticated {
          logger.info(.auth, "User is authenticated")
        } else {
          logger.info(.auth, "User not authenticated - browsing as guest")
        }
        return .none

      case let .didRegisterForRemoteNotificationsWithDeviceToken(token):
        return .run { send in
          await send(.deviceRegistrationResponse(Result {
            try await serverClient.registerDevice(token: token)
          }))
        }

      case .didFailToRegisterForRemoteNotificationsWithError:
        return .none

      case let .deviceRegistrationResponse(.success(response)):
        let endpointArn = response.body.endpointArn
        return .run { _ in
          try await keychainClient.setDeviceData(Device(endpointArn: endpointArn))
        }

      case let .deviceRegistrationResponse(.failure(error)):
        // Check if this is an auth error - user can continue browsing as guest
        if let serverError = error as? ServerClientError,
           case .unauthorized = serverError {
          state.isAuthenticated = false
          state.main.isAuthenticated = false
          state.main.fileList.isAuthenticated = false
          return .run { _ in
            try? await keychainClient.deleteJwtToken()
          }
        }
        return .none

      // Handle delegate actions from LoginFeature (direct login, not from sheet)
      case .login(.delegate(.loginCompleted)),
           .login(.delegate(.registrationCompleted)):
        state.isAuthenticated = true
        state.main.isAuthenticated = true
        state.main.fileList.isAuthenticated = true
        return .none

      // Handle delegate actions from MainFeature's login sheet
      case .main(.delegate(.loginCompleted)),
           .main(.delegate(.registrationCompleted)):
        state.isAuthenticated = true
        state.main.isAuthenticated = true
        state.main.fileList.isAuthenticated = true
        return .none

      case .login:
        return .none

      // Handle auth required from MainFeature - force user to re-login
      case .main(.delegate(.authenticationRequired)):
        state.isAuthenticated = false
        state.main.isAuthenticated = false
        state.main.fileList.isAuthenticated = false
        // Keep registration status - user is still registered, just needs to re-authenticate
        state.login.loginStatus = .unauthenticated
        state.login.alert = nil
        // Present login sheet to force re-authentication
        state.main.loginSheet = LoginFeature.State()
        return .run { [logger, keychainClient] _ in
          // Clear the stored JWT token since it's invalid
          try? await keychainClient.deleteJwtToken()
          logger.info(.auth, "Session expired - presenting login sheet for re-authentication")
        }

      // MARK: - Push Notification Handling
      case let .receivedPushNotification(userInfo):
        let notificationType = PushNotificationType.parse(from: userInfo)
        return .send(.processedPushNotification(notificationType))

      case let .processedPushNotification(notificationType):
        switch notificationType {
        case let .metadata(file):
          // Save metadata to CoreData, then update UI
          return .run { [coreDataClient] send in
            try await coreDataClient.cacheFile(file)
            await send(.fileMetadataSaved(file))
          }

        case let .downloadReady(fileId, key, url, size):
          // Check if file already downloaded, then trigger download if not
          return .run { [fileClient, coreDataClient] send in
            // First update the URL in CoreData
            try await coreDataClient.updateFileUrl(fileId, url)

            // Update the URL in UI state (removes pending status)
            await send(.main(.fileList(.updateFileUrl(fileId: fileId, url: url))))

            // Check if file already exists locally
            if fileClient.fileExists(url) {
              logger.info(.download, "File already downloaded, skipping", metadata: ["fileId": fileId])
              // Still need to refresh state to show as downloaded
              await send(.main(.fileList(.refreshFileState(fileId))))
              return
            }

            await send(.downloadReadyProcessed(fileId: fileId, key: key, url: url, size: size))
          }

        case .unknown:
          logger.warning(.push, "Unknown push notification type")
          return .none
        }

      case let .fileMetadataSaved(file):
        // Forward to MainFeature to update FileList
        return .send(.main(.fileList(.fileAddedFromPush(file))))

      case let .downloadReadyProcessed(fileId, _, url, size):
        // Start background download
        return .run { [logger, downloadClient] send in
          logger.info(.download, "Starting background download", metadata: ["fileId": fileId])
          let stream = downloadClient.downloadFile(url, size)
          for await progress in stream {
            switch progress {
            case .completed:
              await send(.backgroundDownloadCompleted(fileId: fileId))
            case let .failed(message):
              await send(.backgroundDownloadFailed(fileId: fileId, error: message))
            case .progress:
              // Progress updates not needed for background downloads from push
              break
            }
          }
        }

      case let .backgroundDownloadCompleted(fileId):
        logger.info(.download, "Background download completed", metadata: ["fileId": fileId])
        // Mark file as downloaded for metrics tracking, then refresh UI state
        return .run { [coreDataClient] send in
          try? await coreDataClient.markFileDownloaded(fileId)
          await send(.main(.fileList(.refreshFileState(fileId))))
        }

      case let .backgroundDownloadFailed(fileId, error):
        logger.error(.download, "Background download failed", metadata: ["fileId": fileId, "error": error])
        return .none

      case .main:
        return .none

      #if DEBUG
      case .shakeDetected:
        state.diagnostic = DiagnosticFeature.State()
        return .none

      case .diagnostic(.presented(.delegate(.authenticationInvalidated))):
        state.isAuthenticated = false
        state.main.isAuthenticated = false
        state.main.fileList.isAuthenticated = false
        state.login.loginStatus = .unauthenticated
        state.diagnostic = nil  // Dismiss the diagnostic sheet
        return .send(.main(.fileList(.clearAllFiles)))

      case .diagnostic:
        return .none
      #endif
      }
    }
    Scope(state: \.main, action: \.main) {
      MainFeature()
    }
    #if DEBUG
    .ifLet(\.$diagnostic, action: \.diagnostic) {
      DiagnosticFeature()
    }
    #endif
  }
}

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

// MARK: - Launch View
struct LaunchView: View {
  let status: String
  @State private var dotOffset: CGFloat = 0
  @State private var showShapes = false

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
