import ComposableArchitecture
#if DEBUG
  import DiagnosticFeature
#endif
import Foundation
import KeychainClient
import LoggerClient
import PersistenceClient
import SharedModels

/// Authenticated Account screen reducer.
///
/// Sources real identity from the keychain (`keychainClient.getUserData`, the
/// same store `DiagnosticFeature` reads) and the three offline-usage stats from
/// CoreData (`coreDataClient.getMetrics`) — no network call. Navigation to
/// DownloadSettings / Diagnostics and sign-out are delegated UP to the
/// coordinator (`MainFeature`) so this leaf does NOT import sibling features
/// (S77).
@Reducer
public struct ProfileFeature: Sendable {
  public init() {}

  // MARK: - State

  @ObservableState
  public struct State: Equatable {
    public var user: User?
    public var metrics: FileMetrics?
    public var isLoadingMetrics: Bool = false
    #if DEBUG
      public var diagnostic = DiagnosticFeature.State()
    #endif

    public init(
      user: User? = nil,
      metrics: FileMetrics? = nil,
      isLoadingMetrics: Bool = false
    ) {
      self.user = user
      self.metrics = metrics
      self.isLoadingMetrics = isLoadingMetrics
    }
  }

  // MARK: - Action

  public enum Action {
    case onAppear
    case userLoaded(User?)
    case metricsResponse(FileMetrics)
    case downloadSettingsTapped
    case signOutTapped
    #if DEBUG
      case diagnostic(DiagnosticFeature.Action)
    #endif
    case delegate(Delegate)

    @CasePathable
    public enum Delegate: Equatable {
      case signOut
      case openDownloadSettings
    }
  }

  // MARK: - Dependencies

  @Dependency(\.keychainClient) var keychainClient
  @Dependency(\.coreDataClient) var coreDataClient
  @Dependency(\.logger) var logger

  // MARK: - Body

  public var body: some ReducerOf<Self> {
    #if DEBUG
      Scope(state: \.diagnostic, action: \.diagnostic) {
        DiagnosticFeature()
      }
    #endif

    Reduce { state, action in
      switch action {
      case .onAppear:
        state.isLoadingMetrics = true
        let keychainClient = keychainClient
        let coreDataClient = coreDataClient
        let logger = logger
        return .run { send in
          let user = try? await keychainClient.getUserData()
          await send(.userLoaded(user))
          do {
            let metrics = try await coreDataClient.getMetrics()
            await send(.metricsResponse(metrics))
          } catch {
            logger.warning(.performance, "could not load profile metrics: \(error)")
          }
        }

      case let .userLoaded(user):
        state.user = user
        return .none

      case let .metricsResponse(metrics):
        state.isLoadingMetrics = false
        state.metrics = metrics
        return .none

      case .downloadSettingsTapped:
        return .send(.delegate(.openDownloadSettings))

      case .signOutTapped:
        return .send(.delegate(.signOut))

      #if DEBUG
        // Deleting the JWT/userData keychain items (or signing out from the
        // inline diagnostics) invalidates the session — route up so the
        // coordinator clears auth.
        case .diagnostic(.delegate(.authenticationInvalidated)),
             .diagnostic(.delegate(.signedOut)):
          return .send(.delegate(.signOut))

        case .diagnostic:
          return .none
      #endif

      case .delegate:
        return .none
      }
    }
  }
}
