import APIClient
import AuthenticationClient
import ComposableArchitecture
import DesignSystem
import DiagnosticFeature
import DownloadClient
import DownloadTrackingFeature
import FileClient
import KeychainClient
import LiveActivityClient
import LoggerClient
import LoginFeature
import MainFeature
import NotificationRegistrationClient
import PersistenceClient
import ServerClient
import SharedModels
import SwiftUI
import ThumbnailCacheClient
import UserNotifications

// MARK: - Notification Setup Helper

@MainActor
public func setupNotifications() {
  @Dependency(\.notificationRegistrationClient) var notificationRegistrationClient
  let client = notificationRegistrationClient
  let center = UNUserNotificationCenter.current()
  center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
    guard granted else { return }
    UNUserNotificationCenter.current().getNotificationSettings { settings in
      guard settings.authorizationStatus == .authorized else { return }
      Task {
        await client.registerForRemoteNotifications()
      }
    }
  }
}

/// Token refresh threshold - refresh if token expires within this time
private let tokenRefreshThreshold: TimeInterval = 5 * 60 // 5 minutes

// MARK: - RootFeature

@Reducer
public struct RootFeature: Sendable {
  public init() {}

  @ObservableState
  public struct State: Equatable {
    public init() {}
    public var isLaunching: Bool = true
    public var launchStatus: String = "Starting..."
    @Shared(.inMemory("isAuthenticated")) public var isAuthenticated = false
    @Shared(.inMemory("isRegistered")) public var isRegistered = false
    public var login: LoginFeature.State = .init()
    public var main: MainFeature.State = .init()
    public var downloadTracking: DownloadTrackingFeature.State = .init()

    #if DEBUG
      @Presents public var diagnostic: DiagnosticFeature.State?
    #endif
  }

  public enum Action {
    case didFinishLaunching
    case authStateResponse(AuthState)
    case didRegisterForRemoteNotificationsWithDeviceToken(String)
    case didFailToRegisterForRemoteNotificationsWithError(Error)
    case deviceRegistrationResponse(Result<RegisterDeviceResponse, Error>)
    case checkTokenExpiration
    case tokenRefreshResponse(Result<LoginResponse, Error>)
    case receivedPushNotification([AnyHashable: Any])
    case processedPushNotification(PushNotificationType)
    case fileMetadataSaved(File)
    case downloadReadyProcessed(fileId: String, key: String, url: URL, size: Int64)
    case downloadTracking(DownloadTrackingFeature.Action)
    case login(LoginFeature.Action)
    case main(MainFeature.Action)
    case requestDeviceRegistration
    #if DEBUG
      case shakeDetected
      case diagnostic(PresentationAction<DiagnosticFeature.Action>)
    #endif
  }

  private enum CancelID {
    case tokenRefresh
    case deviceRegistration
  }

  @Dependency(\.authenticationClient) var authenticationClient
  @Dependency(\.serverClient) var serverClient
  @Dependency(\.keychainClient) var keychainClient
  @Dependency(\.coreDataClient) var coreDataClient
  @Dependency(\.downloadClient) var downloadClient
  @Dependency(\.fileClient) var fileClient
  @Dependency(\.logger) var logger
  @Dependency(\.notificationRegistrationClient) var notificationRegistrationClient
  @Dependency(\.liveActivityClient) var liveActivityClient
  @Dependency(\.thumbnailCacheClient) var thumbnailCacheClient

  public var body: some ReducerOf<Self> {
    Scope(state: \.login, action: \.login) {
      LoginFeature()
    }
    Scope(state: \.downloadTracking, action: \.downloadTracking) {
      DownloadTrackingFeature()
    }

    Reduce { state, action in
      switch action {
      case .didFinishLaunching:
        state.launchStatus = "Checking authentication..."
        logger.info(.lifecycle, "App launched - checking authentication status")
        return .run { [authenticationClient] send in
          await MainActor.run { setupNotifications() }
          let authState = await authenticationClient.determineAuthState()
          await send(.authStateResponse(authState))
        }

      case let .authStateResponse(authState):
        logger.info(.lifecycle, "Auth state determined", metadata: [
          "loginStatus": "\(authState.loginStatus)",
          "registrationStatus": "\(authState.registrationStatus)",
        ])
        state.isLaunching = false
        state.login.registrationStatus = authState.registrationStatus
        state.$isAuthenticated.withLock { $0 = authState.isAuthenticated }
        state.$isRegistered.withLock { $0 = authState.isRegistered }

        if authState.isAuthenticated {
          logger.info(.auth, "User is authenticated - checking token expiration")
          return .send(.checkTokenExpiration)
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
        .cancellable(id: CancelID.deviceRegistration, cancelInFlight: true)

      case .didFailToRegisterForRemoteNotificationsWithError:
        return .none

      case let .deviceRegistrationResponse(.success(response)):
        let endpointArn = response.body.endpointArn
        return .run { _ in
          try await keychainClient.setDeviceData(Device(endpointArn: endpointArn))
        }

      case let .deviceRegistrationResponse(.failure(error)):
        if let serverError = error as? ServerClientError,
           case .unauthorized = serverError
        {
          state.$isAuthenticated.withLock { $0 = false }
          return .run { _ in
            try? await keychainClient.deleteJwtToken()
            try? await keychainClient.deleteTokenExpiresAt()
          }
        }
        return .none

      case .requestDeviceRegistration:
        logger.info(.push, "Re-requesting device registration with authentication")
        return .run { [notificationRegistrationClient] _ in
          await notificationRegistrationClient.registerForRemoteNotifications()
        }

      case .checkTokenExpiration:
        return .run { [keychainClient, serverClient, logger] send in
          guard let expiresAt = try await keychainClient.getTokenExpiresAt() else {
            logger.info(.auth, "No expiration date stored - skipping refresh check")
            return
          }

          let timeUntilExpiration = expiresAt.timeIntervalSinceNow
          if timeUntilExpiration < tokenRefreshThreshold {
            logger.info(.auth, "Token expires soon (\(Int(timeUntilExpiration))s) - refreshing")
            await send(.tokenRefreshResponse(Result {
              try await serverClient.refreshToken()
            }))
          } else {
            logger.info(.auth, "Token valid for \(Int(timeUntilExpiration))s - no refresh needed")
          }
        }
        .cancellable(id: CancelID.tokenRefresh, cancelInFlight: true)

      case let .tokenRefreshResponse(.success(response)):
        guard let token = response.body?.token else {
          logger.warning(.auth, "Refresh succeeded but no token in response")
          return .none
        }
        let expirationDate = response.body?.expirationDate
        return .run { [keychainClient, logger] _ in
          try await keychainClient.setJwtToken(token)
          if let expirationDate {
            try await keychainClient.setTokenExpiresAt(expirationDate)
          }
          logger.info(.auth, "Token refreshed successfully")
        }

      case let .tokenRefreshResponse(.failure(error)):
        if let serverError = error as? ServerClientError,
           case .unauthorized = serverError
        {
          logger.warning(.auth, "Token refresh failed with 401 - session expired")
          return .send(.main(.delegate(.authenticationRequired)))
        }
        logger.warning(.auth, "Token refresh failed: \(error)")
        return .none

      case .login(.delegate(.loginCompleted)),
           .main(.delegate(.loginCompleted)):
        state.$isAuthenticated.withLock { $0 = true }
        state.$isRegistered.withLock { $0 = true }
        return .none

      case .login(.delegate(.registrationCompleted)),
           .main(.delegate(.registrationCompleted)):
        state.$isAuthenticated.withLock { $0 = true }
        state.$isRegistered.withLock { $0 = true }
        return .send(.requestDeviceRegistration)

      case .login:
        return .none

      case .main(.delegate(.authenticationRequired)):
        state.$isAuthenticated.withLock { $0 = false }
        state.login.loginStatus = .unauthenticated
        state.login.alert = nil
        state.main.loginSheet = LoginFeature.State()
        return .run { [logger, keychainClient] _ in
          try? await keychainClient.deleteJwtToken()
          try? await keychainClient.deleteTokenExpiresAt()
          logger.info(.auth, "Session expired - presenting login sheet for re-authentication")
        }

      case .main(.delegate(.signedOut)):
        state.$isAuthenticated.withLock { $0 = false }
        return .none

      case let .receivedPushNotification(userInfo):
        let notificationType = PushNotificationType.parse(from: userInfo)
        return .send(.processedPushNotification(notificationType))

      case let .processedPushNotification(notificationType):
        switch notificationType {
        case let .metadata(file):
          return .run { [coreDataClient] send in
            try await coreDataClient.cacheFile(file)
            await send(.fileMetadataSaved(file))
          }

        case let .downloadReady(fileId, key, url, size):
          return .run { [fileClient, coreDataClient] send in
            try await coreDataClient.updateFileUrl(fileId, url)
            await send(.main(.fileList(.updateFileUrl(fileId: fileId, url: url))))

            if fileClient.fileExists(url) {
              logger.info(.download, "File already downloaded, skipping", metadata: ["fileId": fileId])
              await send(.main(.fileList(.refreshFileState(fileId))))
              return
            }

            await send(.downloadReadyProcessed(fileId: fileId, key: key, url: url, size: size))
          }

        case let .downloadStarted(fileId, thumbnailUrl, _):
          let thumbnailCacheClient = thumbnailCacheClient
          return .merge(
            .send(.main(.fileList(.fileDownloadStartedOnServer(fileId: fileId, thumbnailUrl: thumbnailUrl)))),
            .run { _ in
              guard let urlString = thumbnailUrl, let url = URL(string: urlString) else { return }
              await thumbnailCacheClient.prefetchThumbnails([(fileId: fileId, url: url)])
            }
          )

        case let .downloadProgress(fileId, progressPercent):
          return .send(.main(.fileList(.serverDownloadProgress(fileId: fileId, percent: progressPercent))))

        case let .failure(fileId, _, _, errorMessage):
          return .run { [coreDataClient, liveActivityClient] send in
            await liveActivityClient.endActivity(fileId: fileId, status: .failed, errorMessage: errorMessage)
            try await coreDataClient.updateFileStatus(fileId, .failed)
            await send(.main(.fileList(.fileFailed(fileId: fileId, error: errorMessage))))
          }

        case .unknown:
          logger.warning(.push, "Unknown push notification type")
          return .none
        }

      case let .fileMetadataSaved(file):
        let thumbnailCacheClient = thumbnailCacheClient
        return .merge(
          .send(.main(.fileList(.fileAddedFromPush(file)))),
          .run { [liveActivityClient] _ in
            await liveActivityClient.startActivity(file)
          },
          .run { _ in
            guard let urlString = file.thumbnailUrl, let url = URL(string: urlString) else { return }
            await thumbnailCacheClient.prefetchThumbnails([(fileId: file.fileId, url: url)])
          }
        )

      case let .downloadReadyProcessed(fileId, key, url, size):
        let title = state.main.fileList.files[id: fileId]?.file.title ?? key
        return .send(.downloadTracking(.startDownload(fileId: fileId, title: title, url: url, size: size)))

      case let .downloadTracking(.delegate(.downloadStarted(fileId, title, isBackground))):
        return .send(.main(.activeDownloads(.downloadStarted(fileId: fileId, title: title, isBackground: isBackground))))

      case let .downloadTracking(.delegate(.downloadProgressUpdated(fileId, percent))):
        return .send(.main(.activeDownloads(.downloadProgressUpdated(fileId: fileId, percent: percent))))

      case let .downloadTracking(.delegate(.downloadCompleted(fileId))):
        return .send(.main(.activeDownloads(.downloadCompleted(fileId: fileId))))

      case let .downloadTracking(.delegate(.downloadFailed(fileId, error))):
        return .send(.main(.activeDownloads(.downloadFailed(fileId: fileId, error: error))))

      case let .downloadTracking(.delegate(.refreshFileState(fileId))):
        return .send(.main(.fileList(.refreshFileState(fileId))))

      case .downloadTracking:
        return .none

      case .main:
        return .none

      #if DEBUG
        case .shakeDetected:
          state.diagnostic = DiagnosticFeature.State()
          return .none

        case .diagnostic(.presented(.delegate(.authenticationInvalidated))):
          state.$isAuthenticated.withLock { $0 = false }
          state.login.loginStatus = .unauthenticated
          state.diagnostic = nil
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
