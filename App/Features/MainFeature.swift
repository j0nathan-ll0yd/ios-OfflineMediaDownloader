import ComposableArchitecture
import Foundation

@Reducer
struct MainFeature {
  @ObservableState
  struct State: Equatable {
    var selectedTab: Tab = .files
    var isAuthenticated: Bool = false
    var fileList: FileListFeature.State = FileListFeature.State()
    var diagnostic: DiagnosticFeature.State = DiagnosticFeature.State()
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
    case presentLoginSheet
    case loginSheet(PresentationAction<LoginFeature.Action>)
    case delegate(Delegate)

    @CasePathable
    enum Delegate: Equatable {
      case authenticationRequired
      case loginCompleted
      case registrationCompleted
    }
  }

  var body: some ReducerOf<Self> {
    Scope(state: \.fileList, action: \.fileList) {
      FileListFeature()
    }

    Scope(state: \.diagnostic, action: \.diagnostic) {
      DiagnosticFeature()
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
        return .send(.delegate(.registrationCompleted))

      case .loginSheet:
        return .none

      // Forward auth required from FileListFeature to parent
      case .fileList(.delegate(.authenticationRequired)):
        return .send(.delegate(.authenticationRequired))

      // Handle login required from FileListFeature ('+' button) - show login sheet
      case .fileList(.delegate(.loginRequired)):
        state.loginSheet = LoginFeature.State()
        return .none

      case .fileList:
        return .none

      case .diagnostic:
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
