import ComposableArchitecture
import Foundation

@Reducer
struct MainFeature {
  @ObservableState
  struct State: Equatable {
    var selectedTab: Tab = .files
    var isAuthenticated: Bool = false
    var isRegistered: Bool = false
    var fileList: FileListFeature.State = FileListFeature.State()
    var diagnostic: DiagnosticFeature.State = DiagnosticFeature.State()
    var accountLogin: LoginFeature.State = LoginFeature.State()
    var activeDownloads: ActiveDownloadsFeature.State = ActiveDownloadsFeature.State()
    @Presents var loginSheet: LoginFeature.State?

    enum Tab: Equatable, Sendable {
      case files
      case account
    }
  }

  enum Action {
    case tabSelected(State.Tab)
    case fileList(FileListFeature.Action)
    case diagnostic(DiagnosticFeature.Action)
    case accountLogin(LoginFeature.Action)
    case activeDownloads(ActiveDownloadsFeature.Action)
    case presentLoginSheet
    case loginSheet(PresentationAction<LoginFeature.Action>)
    case delegate(Delegate)

    @CasePathable
    enum Delegate: Equatable {
      case authenticationRequired
      case loginCompleted
      case registrationCompleted
      case signedOut
    }
  }

  var body: some ReducerOf<Self> {
    Scope(state: \.fileList, action: \.fileList) {
      FileListFeature()
    }

    Scope(state: \.diagnostic, action: \.diagnostic) {
      DiagnosticFeature()
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

      // Handle login completion from sheet - forward to parent
      case .loginSheet(.presented(.delegate(.loginCompleted))):
        state.loginSheet = nil
        return .send(.delegate(.loginCompleted))

      case .loginSheet(.presented(.delegate(.registrationCompleted))):
        state.loginSheet = nil
        // Clear default files (including CoreData) and switch to Files tab
        // No need to refresh - new user has no files yet
        state.selectedTab = .files
        return .concatenate(
          .send(.delegate(.registrationCompleted)),
          .send(.fileList(.clearAllFiles))
        )

      case .loginSheet:
        return .none

      // Handle login completion from embedded account tab login
      case .accountLogin(.delegate(.loginCompleted)):
        return .send(.delegate(.loginCompleted))

      case .accountLogin(.delegate(.registrationCompleted)):
        // Clear default files (including CoreData) and switch to Files tab
        // No need to refresh - new user has no files yet
        state.selectedTab = .files
        return .concatenate(
          .send(.delegate(.registrationCompleted)),
          .send(.fileList(.clearAllFiles))
        )

      case .accountLogin:
        return .none

      // Forward auth required from FileListFeature to parent
      case .fileList(.delegate(.authenticationRequired)):
        return .send(.delegate(.authenticationRequired))

      // Handle login required from FileListFeature ('+' button) - show login sheet
      case .fileList(.delegate(.loginRequired)):
        state.loginSheet = LoginFeature.State()
        return .none

      // Forward download tracking delegates to ActiveDownloadsFeature
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
        state.isAuthenticated = false
        state.fileList.isAuthenticated = false
        // Keep isRegistered - user is still registered, just needs to re-authenticate
        return .concatenate(
          .send(.fileList(.clearAllFiles)),
          .send(.delegate(.authenticationRequired))
        )

      case .diagnostic(.delegate(.signedOut)):
        state.isAuthenticated = false
        state.fileList.isAuthenticated = false
        // Keep isRegistered - user is still registered, just signed out
        // Do NOT clear files - user keeps local content
        return .send(.delegate(.signedOut))

      case .diagnostic:
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
  }
}
