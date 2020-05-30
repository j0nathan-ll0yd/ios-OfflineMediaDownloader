import UIKit
import AuthenticationServices
import Contacts
import Combine

class SignInWithAppleDelegates: NSObject {
  private let signInSucceeded: (Bool) -> Void
  private var cancellableSink: Cancellable?
  private weak var window: UIWindow!
  
  init(window: UIWindow?, onSignedIn: @escaping (Bool) -> Void) {
    self.window = window
    self.signInSucceeded = onSignedIn
  }
}

extension SignInWithAppleDelegates: ASAuthorizationControllerDelegate {
  private func registerNewAccount(credential: ASAuthorizationAppleIDCredential) {
    
    let userData = UserData(
      email: credential.email!,
      firstName: credential.fullName?.givenName ?? "",
      identifier: credential.user,
      lastName: credential.fullName?.familyName ?? ""
    )
    
    print("userData")
    debugPrint(userData)
    
    // see if they are already logged in
    let keychain = UserDataKeychain()
    do {
      try keychain.store(userData)
    } catch let error as NSError {
      print(error.localizedDescription)
      self.signInSucceeded(false)
    }
    
    let authorizationCode = String(decoding: credential.authorizationCode!, as: UTF8.self)
    self.cancellableSink = Server.registerUser(user: userData, authorizationCode: authorizationCode).sink(
      receiveCompletion: { completion in
        if case .failure(let err) = completion {
          print("Retrieving data failed with error \(err)")
          self.signInSucceeded(false)
        }
      },
      receiveValue: { responseCode in
        self.signInSucceeded(true)
      }
    )
  }

  private func signInWithExistingAccount(credential: ASAuthorizationAppleIDCredential) {
    // You *should* have a fully registered account here.  If you get back an error from your server
    // that the account doesn't exist, you can look in the keychain for the credentials and rerun setup
    
    print("signInWithExistingAccount")
    // if (WebAPI.Login(credential.user, credential.identityToken, credential.authorizationCode)) {
    //   ...
    // }
    self.signInSucceeded(true)
  }

  private func signInWithUserAndPassword(credential: ASPasswordCredential) {
    // You *should* have a fully registered account here.  If you get back an error from your server
    // that the account doesn't exist, you can look in the keychain for the credentials and rerun setup

    // if (WebAPI.Login(credential.user, credential.password)) {
    //   ...
    // }
    self.signInSucceeded(true)
  }
  
  func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
    print("authorizationController")
    switch authorization.credential {
    case let appleIdCredential as ASAuthorizationAppleIDCredential:
      if let _ = appleIdCredential.email, let _ = appleIdCredential.fullName {
        registerNewAccount(credential: appleIdCredential)
      } else {
        signInWithExistingAccount(credential: appleIdCredential)
      }

      break
      
    case let passwordCredential as ASPasswordCredential:
      signInWithUserAndPassword(credential: passwordCredential)

      break
      
    default:
      break
    }
  }
  
  func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
    print("authorizationController.didCompleteWithError")
    debugPrint(error)
  }
}

extension SignInWithAppleDelegates: ASAuthorizationControllerPresentationContextProviding {
  func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
    return self.window
  }
}
