import ComposableArchitecture
import Foundation

// MARK: - EmailLoginFeature

/// Email sign-in entry. The backend exposes no email-auth endpoint yet, so
/// `continueButtonTapped` surfaces an "unavailable" alert rather than calling a
/// server. When the endpoint ships, replace the alert with the real request.
@Reducer
public struct EmailLoginFeature: Sendable {
  public init() {}

  @ObservableState
  public struct State: Equatable {
    public var email: String = ""
    @Presents public var alert: AlertState<Action.Alert>?

    public init() {}

    var isContinueEnabled: Bool {
      email.contains("@") && email.contains(".")
    }
  }

  public enum Action: BindableAction {
    case binding(BindingAction<State>)
    case continueButtonTapped
    case alert(PresentationAction<Alert>)

    @CasePathable
    public enum Alert: Equatable {
      case dismiss
    }
  }

  public var body: some ReducerOf<Self> {
    BindingReducer()
    Reduce { state, action in
      switch action {
      case .continueButtonTapped:
        state.alert = AlertState {
          TextState("Email Sign-In Unavailable")
        } actions: {
          ButtonState(role: .cancel, action: .dismiss) {
            TextState("OK")
          }
        } message: {
          TextState("Email sign-in isn't available yet. Please continue with Apple to access your library.")
        }
        return .none

      case .binding, .alert:
        return .none
      }
    }
    .ifLet(\.$alert, action: \.alert)
  }
}
