import UIKit
import SwiftUI
import AuthenticationServices

struct LoginView: View {
  var window: UIWindow?
  @State var appleSignInDelegates: SignInWithAppleDelegates! = nil
  
  init(window: UIWindow) {
    self.window = window
  }

  var body: some View {
    ZStack {
      Color.green.edgesIgnoringSafeArea(.all)

      VStack {
        SignInWithApple()
          .frame(width: 280, height: 60)
          .onTapGesture(perform: showAppleLogin)
      }
    }
    .onAppear {
      self.performExistingAccountSetupFlows()
    }
  }

  private func showAppleLogin() {
    let request = ASAuthorizationAppleIDProvider().createRequest()
    request.requestedScopes = [.fullName, .email]

    performSignIn(using: [request])
  }

  /// Prompts the user if an existing iCloud Keychain credential or Apple ID credential is found.
  private func performExistingAccountSetupFlows() {
    #if !targetEnvironment(simulator)
    // Note that this won't do anything in the simulator.  You need to
    // be on a real device or you'll just get a failure from the call.
    let requests = [
      ASAuthorizationAppleIDProvider().createRequest(),
      ASAuthorizationPasswordProvider().createRequest()
    ]

    //performSignIn(using: requests)
    #endif
    let provider = ASAuthorizationAppleIDProvider()
    let keychain = UserDataKeychain()
    do {
      print("Keychain lookup")
      let userData = try keychain.retrieve()
      debugPrint(userData)
      let userId = userData.identifier
      print(userId)
      provider.getCredentialState(forUserID: userId) { state, error in
        switch state {
        case .authorized:
          print("Credentials are valid.")
          break
        case .revoked:
          print("Credential revoked, log them out")
          break
        case .notFound:
          print("Credentials not found, show login UI")
          break
        case .transferred:
          print("Credentials transferred.")
          break
        @unknown default:
          print("Unknown.")
        }
      }
    } catch let error as NSError {
      print("Keychain error")
      print(error.code)
      print(error.domain)
      print(error.localizedDescription)
      debugPrint(error)
    }
  }

  private func performSignIn(using requests: [ASAuthorizationRequest]) {
    appleSignInDelegates = SignInWithAppleDelegates(window: window) { success in
      if success {
        // update UI
        print("Login Successful")
      } else {
        // show the user an error
      }
    }

    let controller = ASAuthorizationController(authorizationRequests: requests)
    controller.delegate = appleSignInDelegates
    controller.presentationContextProvider = appleSignInDelegates
    controller.performRequests()
  }
}

