import ComposableArchitecture
import Foundation

@Reducer
struct MainFeature {
  @ObservableState
  struct State: Equatable {
    var selectedTab: Tab = .files
    var fileList: FileListFeature.State = FileListFeature.State()
    var diagnostic: DiagnosticFeature.State = DiagnosticFeature.State()

    enum Tab: Equatable, Sendable {
      case files
      case account
    }
  }

  enum Action {
    case tabSelected(State.Tab)
    case fileList(FileListFeature.Action)
    case diagnostic(DiagnosticFeature.Action)
    case delegate(Delegate)

    @CasePathable
    enum Delegate: Equatable {
      case authenticationRequired
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

      // Forward auth required from FileListFeature to parent
      case .fileList(.delegate(.authenticationRequired)):
        return .send(.delegate(.authenticationRequired))

      case .fileList:
        return .none

      case .diagnostic:
        return .none

      case .delegate:
        return .none
      }
    }
  }
}
