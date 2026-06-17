import AuthenticationServices
import UIKit

// MARK: - AppleSignInController

/// Drives a programmatic Sign in with Apple flow so the login screen can use a
/// fully custom-styled button (gradient border + neon glow) instead of the
/// native `SignInWithAppleButton`, while still performing the real
/// `ASAuthorization` request. The view owns an instance and forwards the
/// result back into the TCA store.
@MainActor
final class AppleSignInController: NSObject {
  private var onResult: ((Result<ASAuthorization, Error>) -> Void)?
  private var authController: ASAuthorizationController?

  func start(onResult: @escaping (Result<ASAuthorization, Error>) -> Void) {
    self.onResult = onResult

    let request = ASAuthorizationAppleIDProvider().createRequest()
    request.requestedScopes = [.fullName, .email]
    request.nonce = ""
    request.state = ""

    let controller = ASAuthorizationController(authorizationRequests: [request])
    controller.delegate = self
    controller.presentationContextProvider = self
    authController = controller
    controller.performRequests()
  }

  private func finish(_ result: Result<ASAuthorization, Error>) {
    let callback = onResult
    onResult = nil
    authController = nil
    callback?(result)
  }
}

// MARK: - ASAuthorizationControllerDelegate

extension AppleSignInController: ASAuthorizationControllerDelegate {
  nonisolated func authorizationController(
    controller _: ASAuthorizationController,
    didCompleteWithAuthorization authorization: ASAuthorization
  ) {
    // SAFETY: ASAuthorizationController delivers delegate callbacks on the main thread.
    MainActor.assumeIsolated {
      finish(.success(authorization))
    }
  }

  nonisolated func authorizationController(
    controller _: ASAuthorizationController,
    didCompleteWithError error: Error
  ) {
    // SAFETY: ASAuthorizationController delivers delegate callbacks on the main thread.
    MainActor.assumeIsolated {
      finish(.failure(error))
    }
  }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding

extension AppleSignInController: ASAuthorizationControllerPresentationContextProviding {
  nonisolated func presentationAnchor(for _: ASAuthorizationController) -> ASPresentationAnchor {
    // SAFETY: presentationAnchor is requested on the main thread during presentation.
    MainActor.assumeIsolated {
      let windowScene = UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .first { $0.activationState == .foregroundActive }
      return windowScene?.keyWindow ?? windowScene?.windows.first ?? ASPresentationAnchor()
    }
  }
}
