import Foundation
import Testing
import ComposableArchitecture
@testable import OfflineMediaDownloader

@Suite("LoginFeature Tests")
struct LoginFeatureTests {

  // MARK: - Login Success Tests

  @MainActor
  @Test("Login success stores token and notifies delegate")
  func loginSuccess() async throws {
    let store = TestStore(initialState: LoginFeature.State()) {
      LoginFeature()
    } withDependencies: {
      $0.keychainClient.setJwtToken = { _ in }
    }

    await store.send(.loginResponse(.success(TestData.validLoginResponse))) {
      $0.loginStatus = .authenticated
    }

    await store.receive(\.delegate.loginCompleted)
  }

  @MainActor
  @Test("Login response with nil body shows alert")
  func loginResponseNilBody() async throws {
    let store = TestStore(initialState: LoginFeature.State()) {
      LoginFeature()
    }

    await store.send(.loginResponse(.success(TestData.loginResponseNilBody)))

    await store.receive(\.showError) {
      $0.alert = AlertState {
        TextState("Login Failed")
      } actions: {
        ButtonState(role: .cancel, action: .dismiss) {
          TextState("OK")
        }
      } message: {
        TextState("Invalid response: missing token")
      }
    }
  }

  // MARK: - Login Failure Tests

  @MainActor
  @Test("Login failure shows alert")
  func loginFailure() async throws {
    let store = TestStore(initialState: LoginFeature.State()) {
      LoginFeature()
    }

    await store.send(.loginResponse(.failure(TestData.TestNetworkError.serverError)))

    await store.receive(\.showError) {
      $0.alert = AlertState {
        TextState("Server Error")
      } actions: {
        ButtonState(role: .cancel, action: .dismiss) {
          TextState("OK")
        }
      } message: {
        TextState("Internal server error")
      }
    }
  }

  @MainActor
  @Test("Network error during login shows connection alert")
  func loginNetworkError() async throws {
    let store = TestStore(initialState: LoginFeature.State()) {
      LoginFeature()
    }

    await store.send(.loginResponse(.failure(TestData.TestNetworkError.notConnected)))

    await store.receive(\.showError) {
      $0.alert = AlertState {
        TextState("No Connection")
      } actions: {
        ButtonState(role: .cancel, action: .dismiss) {
          TextState("OK")
        }
      } message: {
        TextState("Please check your internet connection and try again.")
      }
    }
  }

  // MARK: - Registration Success Tests

  @MainActor
  @Test("Registration success stores token, user data, and notifies delegate")
  func registrationSuccess() async throws {
    var state = LoginFeature.State()
    state.pendingUserData = TestData.sampleUser

    let store = TestStore(initialState: state) {
      LoginFeature()
    } withDependencies: {
      $0.keychainClient.setJwtToken = { _ in }
      $0.keychainClient.setUserData = { _ in }
    }

    await store.send(.registrationResponse(.success(TestData.validLoginResponse))) {
      $0.registrationStatus = .registered
      $0.loginStatus = .authenticated
    }

    await store.receive(\.delegate.registrationCompleted)
  }

  @MainActor
  @Test("Registration response with nil body shows alert")
  func registrationResponseNilBody() async throws {
    var state = LoginFeature.State()
    state.pendingUserData = TestData.sampleUser

    let store = TestStore(initialState: state) {
      LoginFeature()
    }

    await store.send(.registrationResponse(.success(TestData.loginResponseNilBody)))

    await store.receive(\.showError) {
      $0.alert = AlertState {
        TextState("Registration Failed")
      } actions: {
        ButtonState(role: .cancel, action: .dismiss) {
          TextState("OK")
        }
      } message: {
        TextState("Invalid response: missing token")
      }
    }
  }

  // MARK: - Registration Failure Tests

  @MainActor
  @Test("Registration failure preserves pending user data")
  func registrationFailurePreservesData() async throws {
    var state = LoginFeature.State()
    state.pendingUserData = TestData.sampleUser

    let store = TestStore(initialState: state) {
      LoginFeature()
    }

    await store.send(.registrationResponse(.failure(TestData.TestNetworkError.serverError)))

    await store.receive(\.showError) {
      $0.alert = AlertState {
        TextState("Server Error")
      } actions: {
        ButtonState(role: .cancel, action: .dismiss) {
          TextState("OK")
        }
      } message: {
        TextState("Internal server error")
      }
    }

    // Verify pendingUserData is still set
    #expect(store.state.pendingUserData == TestData.sampleUser)
  }

  // MARK: - Sign in with Apple Error Tests
  // Note: ASAuthorization cannot be easily mocked, so we only test error handling

  @MainActor
  @Test("Sign in with Apple failure shows alert")
  func signInWithAppleFailure() async throws {
    let store = TestStore(initialState: LoginFeature.State()) {
      LoginFeature()
    }

    await store.send(.signInWithAppleButtonTapped(.failure(TestData.TestNetworkError.serverError)))

    await store.receive(\.showError) {
      $0.alert = AlertState {
        TextState("Server Error")
      } actions: {
        ButtonState(role: .cancel, action: .dismiss) {
          TextState("OK")
        }
      } message: {
        TextState("Internal server error")
      }
    }
  }

  // MARK: - Login Button Tests

  @MainActor
  @Test("Login button clears alert")
  func loginButtonClearsAlert() async throws {
    var state = LoginFeature.State()
    state.alert = AlertState {
      TextState("Previous Error")
    } actions: {
      ButtonState(role: .cancel, action: .dismiss) {
        TextState("OK")
      }
    }

    let store = TestStore(initialState: state) {
      LoginFeature()
    }

    await store.send(.loginButtonTapped) {
      $0.alert = nil
    }
  }

  // MARK: - Initial State Tests

  @MainActor
  @Test("Initial state is unauthenticated and unregistered")
  func initialState() async throws {
    let state = LoginFeature.State()
    #expect(state.loginStatus == .unauthenticated)
    #expect(state.registrationStatus == .unregistered)
    #expect(state.alert == nil)
    #expect(state.pendingUserData == nil)
  }

  // MARK: - ShowError Tests

  @MainActor
  @Test("ShowError action creates alert state")
  func showErrorCreatesAlert() async throws {
    let store = TestStore(initialState: LoginFeature.State()) {
      LoginFeature()
    }

    await store.send(.showError(.invalidAppleCredential)) {
      $0.alert = AlertState {
        TextState("Sign In Failed")
      } actions: {
        ButtonState(role: .cancel, action: .dismiss) {
          TextState("OK")
        }
      } message: {
        TextState("Could not verify your Apple ID credentials. Please try again.")
      }
    }
  }

  @MainActor
  @Test("Alert dismiss clears alert state")
  func alertDismissClearsState() async throws {
    var state = LoginFeature.State()
    state.alert = AlertState {
      TextState("Test")
    } actions: {
      ButtonState(role: .cancel, action: .dismiss) {
        TextState("OK")
      }
    }

    let store = TestStore(initialState: state) {
      LoginFeature()
    }

    await store.send(.alert(.dismiss)) {
      $0.alert = nil
    }
  }
}
