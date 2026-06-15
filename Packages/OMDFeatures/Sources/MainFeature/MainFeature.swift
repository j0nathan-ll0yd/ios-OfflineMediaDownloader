import ActiveDownloadsFeature
import ComposableArchitecture
import DiagnosticFeature
import FileListFeature
import Foundation
import LoginFeature
import ProfileFeature
import SharedModels

@Reducer
public struct MainFeature: Sendable {
  public init() {}

  @ObservableState
  public struct State: Equatable {
    public var selectedTab: Tab = .files
    @Shared(.inMemory("isAuthenticated")) public var isAuthenticated = false
    @Shared(.inMemory("isRegistered")) public var isRegistered = false
    public var fileList: FileListFeature.State = .init()
    public var diagnostic: DiagnosticFeature.State = .init()
    public var profile: ProfileFeature.State = .init()
    public var accountLogin: LoginFeature.State = .init()
    public var activeDownloads: ActiveDownloadsFeature.State = .init()
    @Presents public var loginSheet: LoginFeature.State?
    @Presents public var accountDestination: AccountDestination.State?

    public enum Tab: Equatable, Sendable {
      case files
      case account
    }

    public init() {}
  }

  public enum Action {
    case tabSelected(State.Tab)
    case fileList(FileListFeature.Action)
    case diagnostic(DiagnosticFeature.Action)
    case profile(ProfileFeature.Action)
    case accountLogin(LoginFeature.Action)
    case activeDownloads(ActiveDownloadsFeature.Action)
    case presentLoginSheet
    case loginSheet(PresentationAction<LoginFeature.Action>)
    case accountDestination(PresentationAction<AccountDestination.Action>)
    case delegate(Delegate)

    @CasePathable
    public enum Delegate: Equatable {
      case authenticationRequired
      case loginCompleted
      case registrationCompleted
      case signedOut
    }
  }

  @Reducer(state: .equatable)
  public enum AccountDestination {
    case downloadSettings(DownloadSettingsFeature)
    case diagnostics(DiagnosticFeature)
  }

  public var body: some ReducerOf<Self> {
    Scope(state: \.fileList, action: \.fileList) {
      FileListFeature()
    }

    Scope(state: \.diagnostic, action: \.diagnostic) {
      DiagnosticFeature()
    }

    Scope(state: \.profile, action: \.profile) {
      ProfileFeature()
    }

    Scope(state: \.accountLogin, action: \.accountLogin) {
      LoginFeature()
    }

    Scope(state: \.activeDownloads, action: \.activeDownloads) {
      ActiveDownloadsFeature()
    }

    Reduce { state, action in
      switch action {
      case let .tabSelected(tab):
        state.selectedTab = tab
        return .none

      case .presentLoginSheet:
        state.loginSheet = LoginFeature.State()
        return .none

      case .loginSheet(.presented(.delegate(.loginCompleted))):
        state.loginSheet = nil
        return .send(.delegate(.loginCompleted))

      case .loginSheet(.presented(.delegate(.registrationCompleted))):
        state.loginSheet = nil
        state.selectedTab = .files
        return .run { send in
          await send(.delegate(.registrationCompleted))
          await send(.fileList(.clearAllFiles))
        }

      case .loginSheet:
        return .none

      case .accountLogin(.delegate(.loginCompleted)):
        return .send(.delegate(.loginCompleted))

      case .accountLogin(.delegate(.registrationCompleted)):
        state.selectedTab = .files
        return .run { send in
          await send(.delegate(.registrationCompleted))
          await send(.fileList(.clearAllFiles))
        }

      case .accountLogin:
        return .none

      case .fileList(.delegate(.authenticationRequired)):
        return .send(.delegate(.authenticationRequired))

      case .fileList(.delegate(.loginRequired)):
        state.loginSheet = LoginFeature.State()
        return .none

      case let .fileList(.delegate(.downloadStarted(file))):
        let title = file.title ?? file.key
        return .send(.activeDownloads(.downloadStarted(fileId: file.fileId, title: title, isBackground: false)))

      case let .fileList(.delegate(.downloadProgressUpdated(fileId, percent))):
        return .send(.activeDownloads(.downloadProgressUpdated(fileId: fileId, percent: percent)))

      case let .fileList(.delegate(.downloadCompleted(fileId))):
        return .send(.activeDownloads(.downloadCompleted(fileId: fileId)))

      case let .fileList(.delegate(.downloadFailed(fileId, error))):
        return .send(.activeDownloads(.downloadFailed(fileId: fileId, error: error)))

      case .fileList:
        return .none

      case .diagnostic(.delegate(.authenticationInvalidated)):
        state.$isAuthenticated.withLock { $0 = false }
        return .run { send in
          await send(.fileList(.clearAllFiles))
          await send(.delegate(.authenticationRequired))
        }

      case .diagnostic(.delegate(.signedOut)):
        state.$isAuthenticated.withLock { $0 = false }
        return .send(.delegate(.signedOut))

      case .diagnostic:
        return .none

      case .profile(.delegate(.signOut)):
        state.$isAuthenticated.withLock { $0 = false }
        return .send(.delegate(.signedOut))

      case .profile(.delegate(.openDownloadSettings)):
        state.accountDestination = .downloadSettings(DownloadSettingsFeature.State())
        return .none

      case .profile(.delegate(.openDiagnostics)):
        state.accountDestination = .diagnostics(DiagnosticFeature.State())
        return .none

      case .profile:
        return .none

      case .accountDestination:
        return .none

      case .activeDownloads:
        return .none

      case .delegate:
        return .none
      }
    }
    .ifLet(\.$loginSheet, action: \.loginSheet) {
      LoginFeature()
    }
    .ifLet(\.$accountDestination, action: \.accountDestination)
  }
}
