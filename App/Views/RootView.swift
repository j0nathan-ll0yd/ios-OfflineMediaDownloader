import SwiftUI
import ComposableArchitecture
import UserNotifications

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
    var main: MainFeature.State?
  }

  enum Action {
    case didFinishLaunching
    case loginStatusResponse(LoginStatus)
    case setRegistrationStatus(RegistrationStatus)
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
        return .run { [logger, authenticationClient] send in
          let loginStatus = try await authenticationClient.determineLoginStatus()
          logger.info(.lifecycle, "Auth check complete", metadata: ["status": "\(loginStatus)"])
          await send(.loginStatusResponse(loginStatus))
        }

      case let .loginStatusResponse(loginStatus):
        logger.info(.lifecycle, "Processing login status", metadata: ["status": "\(loginStatus)"])
        state.isLaunching = false  // Now safe to show appropriate screen
        if loginStatus == .authenticated {
          logger.info(.auth, "User is authenticated - showing main view")
          state.isAuthenticated = true
          state.main = MainFeature.State()
        } else {
          logger.info(.auth, "User not authenticated - showing login view")
          // Check if user was previously registered (has identifier in keychain)
          // This updates the login screen to show correct registration status
          return .run { [logger, keychainClient] send in
            let isRegistered = (try? await keychainClient.getUserIdentifier()) != nil
            logger.info(.auth, "User registration status", metadata: ["registered": isRegistered ? "true" : "false"])
            if isRegistered {
              await send(.setRegistrationStatus(.registered))
            }
          }
        }
        return .none

      case let .setRegistrationStatus(status):
        logger.debug(.auth, "Setting registration status", metadata: ["status": "\(status)"])
        state.login.registrationStatus = status
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
        // Check if this is an auth error - redirect to login
        if let serverError = error as? ServerClientError, serverError == .unauthorized {
          state.isAuthenticated = false
          state.main = nil
          state.login = LoginFeature.State()
          return .run { _ in
            try? await keychainClient.deleteJwtToken()
          }
        }
        return .none

      // Handle delegate actions from LoginFeature
      case .login(.delegate(.loginCompleted)),
           .login(.delegate(.registrationCompleted)):
        state.isAuthenticated = true
        state.main = MainFeature.State()
        return .none

      case .login:
        return .none

      // Handle auth required from MainFeature - redirect to login
      case .main(.delegate(.authenticationRequired)):
        state.isAuthenticated = false
        state.main = nil
        // Keep registration status if user was previously registered
        state.login.loginStatus = .unauthenticated
        state.login.alert = nil
        return .run { [logger, keychainClient] _ in
          // Check if user is registered (has identifier in keychain)
          let isRegistered = (try? await keychainClient.getUserIdentifier()) != nil
          // Clear the stored JWT token since it's invalid
          try? await keychainClient.deleteJwtToken()
          // Note: registrationStatus preserved from previous state
          logger.info(.auth, "Session expired - redirecting to login", metadata: ["registered": isRegistered ? "true" : "false"])
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
        // Forward to MainFeature to refresh file state
        return .send(.main(.fileList(.refreshFileState(fileId))))

      case let .backgroundDownloadFailed(fileId, error):
        logger.error(.download, "Background download failed", metadata: ["fileId": fileId, "error": error])
        return .none

      case .main:
        return .none
      }
    }
    .ifLet(\.main, action: \.main) {
      MainFeature()
    }
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
      } else if store.isAuthenticated, let mainStore = store.scope(state: \.main, action: \.main) {
        MainView(store: mainStore)
      } else {
        LoginView(store: store.scope(state: \.login, action: \.login))
      }
    }
  }
}

// MARK: - Launch View
struct LaunchView: View {
  let status: String

  var body: some View {
    ZStack {
      yellow.edgesIgnoringSafeArea(.all)
      VStack(spacing: 24) {
        LogoView()
        VStack(spacing: 12) {
          ProgressView()
            .scaleEffect(1.2)
            .tint(.black)
          Text(status)
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
      }
    }
  }
}

#Preview {
  RootView(store: Store(initialState: RootFeature.State()) {
    RootFeature()
  })
}
