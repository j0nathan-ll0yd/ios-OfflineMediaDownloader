import SwiftUI
import ComposableArchitecture
import UserNotifications

// MARK: - Notification Setup Helper

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

// MARK: - RootFeature

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

    // Download initiation tracking - blocks UI until first progress received
    var initiatingDownloads: IdentifiedArrayOf<DownloadInitiation> = []
    var isBlockingForDownloadInitiation: Bool { !initiatingDownloads.isEmpty }

    struct DownloadInitiation: Equatable, Identifiable {
      var id: String { fileId }
      let fileId: String
      let title: String
    }

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
    // Download initiation tracking
    case downloadFirstProgressReceived(fileId: String)
    case downloadInitiationTimeout(fileId: String)
    case login(LoginFeature.Action)
    case main(MainFeature.Action)
    case requestDeviceRegistration
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
        // Propagate registration status to MainFeature
        state.main.isRegistered = authState.isRegistered
        state.main.fileList.isRegistered = authState.isRegistered

        if authState.isAuthenticated {
          logger.info(.auth, "User is authenticated")
        } else if authState.isRegistered {
          logger.info(.auth, "User registered but not authenticated - signed out")
        } else {
          logger.info(.auth, "User not registered - browsing as guest")
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

      case .requestDeviceRegistration:
        logger.info(.push, "Re-requesting device registration with authentication")
        return .run { _ in
          await MainActor.run {
            UIApplication.shared.registerForRemoteNotifications()
          }
        }

      // Handle delegate actions from LoginFeature (direct login, not from sheet)
      case .login(.delegate(.loginCompleted)),
           .login(.delegate(.registrationCompleted)):
        state.isAuthenticated = true
        state.main.isAuthenticated = true
        state.main.fileList.isAuthenticated = true
        // User is now registered (login/registration completed)
        state.main.isRegistered = true
        state.main.fileList.isRegistered = true
        return .send(.requestDeviceRegistration)

      // Handle delegate actions from MainFeature's login sheet
      case .main(.delegate(.loginCompleted)),
           .main(.delegate(.registrationCompleted)):
        state.isAuthenticated = true
        state.main.isAuthenticated = true
        state.main.fileList.isAuthenticated = true
        // User is now registered (login/registration completed)
        state.main.isRegistered = true
        state.main.fileList.isRegistered = true
        return .send(.requestDeviceRegistration)

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

      case .main(.delegate(.signedOut)):
        state.isAuthenticated = false
        state.main.isAuthenticated = false
        // Keep login.registrationStatus = .registered so user can log back in
        return .none

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

        case let .failure(fileId, _, _, errorMessage):
          // Update file status to failed in CoreData and UI, end Live Activity
          return .run { [coreDataClient] send in
            await LiveActivityManager.shared.endActivity(fileId: fileId, status: .failed, errorMessage: errorMessage)
            try await coreDataClient.updateFileStatus(fileId, .failed)
            await send(.main(.fileList(.fileFailed(fileId: fileId, error: errorMessage))))
          }

        case .unknown:
          logger.warning(.push, "Unknown push notification type")
          return .none
        }

      case let .fileMetadataSaved(file):
        // Forward to MainFeature to update FileList and start Live Activity
        return .merge(
          .send(.main(.fileList(.fileAddedFromPush(file)))),
          .run { _ in
            await LiveActivityManager.shared.startActivity(for: file)
          }
        )

      case let .downloadReadyProcessed(fileId, key, url, size):
        // Get title from files list or use key as fallback
        let title = state.main.fileList.files[id: fileId]?.file.title ?? key
        // Track download initiation - shows blocking overlay
        state.initiatingDownloads.append(State.DownloadInitiation(fileId: fileId, title: title))
        // Start background download and update Live Activity
        return .merge(
          .send(.main(.activeDownloads(.downloadStarted(fileId: fileId, title: title, isBackground: true)))),
          .run { [logger, downloadClient] send in
            logger.info(.download, "Starting background download", metadata: ["fileId": fileId])
            await LiveActivityManager.shared.updateProgress(fileId: fileId, percent: 0, status: .downloading)
            let stream = downloadClient.downloadFile(url, size)
            var firstProgressReceived = false
            for await progress in stream {
              switch progress {
              case .completed:
                await send(.backgroundDownloadCompleted(fileId: fileId))
              case let .failed(message):
                await send(.backgroundDownloadFailed(fileId: fileId, error: message))
              case let .progress(percent):
                // Dismiss overlay on first progress event
                if !firstProgressReceived {
                  firstProgressReceived = true
                  await send(.downloadFirstProgressReceived(fileId: fileId))
                }
                await LiveActivityManager.shared.updateProgress(fileId: fileId, percent: percent, status: .downloading)
                // Forward progress to in-app tracking
                await send(.main(.activeDownloads(.downloadProgressUpdated(fileId: fileId, percent: percent))))
              }
            }
          },
          // Safety timeout - dismiss overlay after 10 seconds even if no progress
          .run { send in
            try? await Task.sleep(for: .seconds(10))
            await send(.downloadInitiationTimeout(fileId: fileId))
          }
        )

      case let .backgroundDownloadCompleted(fileId):
        logger.info(.download, "Background download completed", metadata: ["fileId": fileId])
        // Remove from initiating downloads (in case overlay is still showing)
        state.initiatingDownloads.remove(id: fileId)
        // Mark file as downloaded for metrics tracking, end Live Activity, then refresh UI state
        return .merge(
          .run { [coreDataClient] send in
            await LiveActivityManager.shared.endActivity(fileId: fileId, status: .downloaded)
            try? await coreDataClient.markFileDownloaded(fileId)
            await send(.main(.fileList(.refreshFileState(fileId))))
          },
          .send(.main(.activeDownloads(.downloadCompleted(fileId: fileId))))
        )

      case let .backgroundDownloadFailed(fileId, error):
        logger.error(.download, "Background download failed", metadata: ["fileId": fileId, "error": error])
        // Remove from initiating downloads (in case overlay is still showing)
        state.initiatingDownloads.remove(id: fileId)
        // End Live Activity with failed status
        return .merge(
          .run { _ in
            await LiveActivityManager.shared.endActivity(fileId: fileId, status: .failed, errorMessage: error)
          },
          .send(.main(.activeDownloads(.downloadFailed(fileId: fileId, error: error))))
        )

      case let .downloadFirstProgressReceived(fileId):
        // Dismiss the blocking overlay - download has started
        state.initiatingDownloads.remove(id: fileId)
        return .none

      case let .downloadInitiationTimeout(fileId):
        // Safety timeout - dismiss overlay even if no progress received
        // This prevents the overlay from blocking indefinitely
        if state.initiatingDownloads[id: fileId] != nil {
          logger.warning(.download, "Download initiation timed out", metadata: ["fileId": fileId])
          state.initiatingDownloads.remove(id: fileId)
        }
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
