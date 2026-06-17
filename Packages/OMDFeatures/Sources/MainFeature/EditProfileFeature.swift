import ComposableArchitecture
import Foundation
import KeychainClient
import SharedModels

/// Edits the locally-stored profile (first/last name) and persists it to the
/// keychain — the same `UserData` record `ProfileFeature` and `DiagnosticFeature`
/// read. Email is sourced from Sign in with Apple and shown read-only. On save,
/// the updated user is delegated up so the Account screen reflects it
/// immediately. There is no server profile-update endpoint yet, so this is a
/// local-only edit.
@Reducer
public struct EditProfileFeature: Sendable {
  public init() {}

  @ObservableState
  public struct State: Equatable {
    public var firstName: String = ""
    public var lastName: String = ""
    public var email: String = ""
    public var isSaving: Bool = false
    var originalUser: User?

    public init(user: User? = nil) {
      if let user {
        firstName = user.firstName
        lastName = user.lastName
        email = user.email
        originalUser = user
      }
    }

    var canSave: Bool {
      let first = firstName.trimmingCharacters(in: .whitespaces)
      let last = lastName.trimmingCharacters(in: .whitespaces)
      return !(first.isEmpty && last.isEmpty)
    }
  }

  public enum Action: BindableAction {
    case binding(BindingAction<State>)
    case onAppear
    case userLoaded(User?)
    case saveButtonTapped
    case saveCompleted(User)
    case delegate(Delegate)

    @CasePathable
    public enum Delegate: Equatable {
      case saved(User)
    }
  }

  @Dependency(\.keychainClient) var keychainClient

  public var body: some ReducerOf<Self> {
    BindingReducer()
    Reduce { state, action in
      switch action {
      case .onAppear:
        // Seeded with the user from the Account screen; load lazily only if not.
        guard state.originalUser == nil else { return .none }
        let keychainClient = keychainClient
        return .run { send in
          let user = try? await keychainClient.getUserData()
          await send(.userLoaded(user))
        }

      case let .userLoaded(user):
        guard let user else { return .none }
        state.firstName = user.firstName
        state.lastName = user.lastName
        state.email = user.email
        state.originalUser = user
        return .none

      case .saveButtonTapped:
        state.isSaving = true
        let updated = User(
          email: state.email,
          firstName: state.firstName.trimmingCharacters(in: .whitespaces),
          identifier: state.originalUser?.identifier ?? "",
          lastName: state.lastName.trimmingCharacters(in: .whitespaces)
        )
        let keychainClient = keychainClient
        return .run { send in
          try? await keychainClient.setUserData(updated)
          await send(.saveCompleted(updated))
        }

      case let .saveCompleted(user):
        state.isSaving = false
        return .send(.delegate(.saved(user)))

      case .binding, .delegate:
        return .none
      }
    }
  }
}
