import SwiftUI
import Combine
import AuthenticationServices

final class LoginViewModel: ObservableObject, Identifiable {
  private var cancellableSink: Cancellable?
  
  func handleCompletion(result: Result<ASAuthorization, Error>) {
    switch result {
    case .success(let authorization):
      //Handle autorization
      print("Login successful")
      if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
        debugPrint(appleIDCredential)
        // TODO: If user already registered in the past; but deleted the App; they would NOT send the email param; but would be unregistered
        // This is done using the https://developer.apple.com/documentation/sign_in_with_apple/revoke_tokens endpoint
        // email will only exist on register, not login
        if (appleIDCredential.email != nil) {
          handleRegisterUser(credential: appleIDCredential)
        }
        else {
          handleSignIn(credential: appleIDCredential)
        }
      }
      break
    case .failure(let error):
      print("Login error")
      print(error)
      // Dismissed the login dialog
      //Handle error
      break
    }
  }
  
  func handleRegisterUser(credential: ASAuthorizationAppleIDCredential) {
    print("LoginViewModel.handleRegisterUser")
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
    }
    
    let authorizationCode = String(decoding: credential.authorizationCode!, as: UTF8.self)
    self.cancellableSink = Server.registerUser(user: userData, authorizationCode: authorizationCode).sink(
      receiveCompletion: { completion in
        if case .failure(let err) = completion {
          print("Retrieving data failed with error \(err)")
        }
      },
      receiveValue: { response in
        let token = Token(decoded: response.body.token)
        KeychainHelper.storeToken(token: token)
        EventHelper.emit(event: RegistrationComplete())
        // This is required to remove the device from the "unregistered user push topic"
        DispatchQueue.main.async {
          UIApplication.shared.registerForRemoteNotifications()
        }
      }
    )
  }
  
  func handleSignIn(credential: ASAuthorizationAppleIDCredential) {
    print("LoginViewModel.handleSignIn")
    let authorizationCode = String(decoding: credential.authorizationCode!, as: UTF8.self)
    self.cancellableSink = Server.loginUser(authorizationCode: authorizationCode).sink(
      receiveCompletion: { completion in
        if case .failure(let err) = completion {
          print("Retrieving data failed with error \(err)")
        }
      },
      receiveValue: { response in
        guard response.body != nil else {
          print("Error occured")
          return
        }
        let token = Token(decoded: response.body!.token)
        KeychainHelper.storeToken(token: token)
        EventHelper.emit(event: LoginComplete())
      }
    )
  }
}
