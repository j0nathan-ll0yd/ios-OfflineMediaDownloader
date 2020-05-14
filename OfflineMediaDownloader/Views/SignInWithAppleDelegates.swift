import UIKit
import AuthenticationServices
import Contacts

class SignInWithAppleDelegates: NSObject {
  private let signInSucceeded: (Bool) -> Void
  private weak var window: UIWindow!
  
  init(window: UIWindow?, onSignedIn: @escaping (Bool) -> Void) {
    self.window = window
    self.signInSucceeded = onSignedIn
  }
}

extension SignInWithAppleDelegates: ASAuthorizationControllerDelegate {
  private func registerNewAccount(credential: ASAuthorizationAppleIDCredential) {
    let name = PersonNameComponentsFormatter.localizedString(from: credential.fullName!, style: .long)
    let userData = UserData(email: credential.email!, identifier: credential.user)
    
    // see if they are already logged in
    let keychain = UserDataKeychain()
    do {
      print("Storing keychain")
      try keychain.store(userData)
    } catch let error as NSError {
      print("Keychain error")
      print(error.code)
      print(error.domain)
      print(error.localizedDescription)
      print(error.debugDescription)
      print("Storing keychain -- FAILED")
      self.signInSucceeded(false)
      debugPrint(error)
    }
    
    do {
      //let success = try WebApi.Register(user: userData, identityToken: credential.identityToken, authorizationCode: credential.authorizationCode)
      print("registerNewAccount")
      print(credential.email!) // 28ncci33a3@privaterelay.appleid.com
      print(credential.realUserStatus.rawValue) // 1 (unknown), 2 (likelyReal), 0 (unsupported)
      print(credential.fullName!) // givenName: Jonathan familyName: Lloyd
      print(credential.user) // 000185.7720315570fc49d99a265f9af4b46879.2034
      debugPrint(credential.identityToken!)
      debugPrint(credential.authorizationCode!)
      print(String(decoding: credential.identityToken!, as: UTF8.self)) // eyJraWQiOiJlWGF1bm1MIiwiYWxnIjoiUlMyNTYifQ.eyJpc3MiOiJodHRwczovL2FwcGxlaWQuYXBwbGUuY29tIiwiYXVkIjoibGlmZWdhbWVzLk9mZmxpbmVNZWRpYURvd25sb2FkZXIiLCJleHAiOjE1ODk0MjY4ODAsImlhdCI6MTU4OTQyNjI4MCwic3ViIjoiMDAwMTg1Ljc3MjAzMTU1NzBmYzQ5ZDk5YTI2NWY5YWY0YjQ2ODc5LjIwMzQiLCJjX2hhc2giOiJ1OE5nQ25WbTF4VzZLLUtsOE92VTFnIiwiZW1haWwiOiIyOG5jY2kzM2EzQHByaXZhdGVyZWxheS5hcHBsZWlkLmNvbSIsImVtYWlsX3ZlcmlmaWVkIjoidHJ1ZSIsImlzX3ByaXZhdGVfZW1haWwiOiJ0cnVlIiwiYXV0aF90aW1lIjoxNTg5NDI2MjgwLCJub25jZV9zdXBwb3J0ZWQiOnRydWV9.emxQ5eT6xrGoMuD3Ivp-sXI1KEOIU5dL1x5C6m5ziHiFjipiGt9gtTSkp4DbKYye93ZyNaM8pDaIq8AeWi3qmRNFpCt6mCrHks-kifSqVFTNxrflYxKjX3M1jOYXe0vHvsn1jGmp81j1iJ279-N58zLJCZkMf50YYLEg6E_jceNQSQxiNXundhTkEdqQ_7JNOycHkEuoCB_1MuRABMXQ6KjiRvprmR1bfIRh7aMbpG9Acp-rc1mP5ZQVhf8mqcEoNt3FhZCQTtvfKorqucGMgeTRqM8gMnL5tZUhqABbQdUXyzArvdNy2mAzZdm2z9jrrSVjuaQ6eu-upuXL_i97Og
      print(String(decoding: credential.authorizationCode!, as: UTF8.self)) // c5ff79e9a047d41af83655511d304d2cc.0.nryv.h4FWj0wZc-XC-uD1hfqiqw
      self.signInSucceeded(true)
    } catch {
      self.signInSucceeded(false)
    }
  }

  private func signInWithExistingAccount(credential: ASAuthorizationAppleIDCredential) {
    // You *should* have a fully registered account here.  If you get back an error from your server
    // that the account doesn't exist, you can look in the keychain for the credentials and rerun setup
    
    print("signInWithExistingAccount")
    print(credential.realUserStatus.rawValue) // 1 (unknown), 2 (likelyReal), 0 (unsupported)
    print(credential.fullName!) // givenName: Jonathan familyName: Lloyd
    print(credential.user) // 000185.7720315570fc49d99a265f9af4b46879.2034
    debugPrint(credential.identityToken!)
    debugPrint(credential.authorizationCode!)
    print(String(decoding: credential.identityToken!, as: UTF8.self)) // eyJraWQiOiI4NkQ4OEtmIiwiYWxnIjoiUlMyNTYifQ.eyJpc3MiOiJodHRwczovL2FwcGxlaWQuYXBwbGUuY29tIiwiYXVkIjoibGlmZWdhbWVzLk9mZmxpbmVNZWRpYURvd25sb2FkZXIiLCJleHAiOjE1ODk0Mjc4NzEsImlhdCI6MTU4OTQyNzI3MSwic3ViIjoiMDAwMTg1Ljc3MjAzMTU1NzBmYzQ5ZDk5YTI2NWY5YWY0YjQ2ODc5LjIwMzQiLCJjX2hhc2giOiJtQXV1M2dvRk5tbGJHOS1EMVBXLVZnIiwiZW1haWwiOiIyOG5jY2kzM2EzQHByaXZhdGVyZWxheS5hcHBsZWlkLmNvbSIsImVtYWlsX3ZlcmlmaWVkIjoidHJ1ZSIsImlzX3ByaXZhdGVfZW1haWwiOiJ0cnVlIiwiYXV0aF90aW1lIjoxNTg5NDI3MjcxLCJub25jZV9zdXBwb3J0ZWQiOnRydWV9.OXn_dXItA_9AQTp4RJFwd91NOqgd3dLsrR-cL5EEr5hoAZSu0gbf2U7E09CChFjF-rXqkBV1FyHbCTqvgLA5shAa3tLExmIsvGoDj59vPw67xoaIikUGv_kkDdyRga9EafGdzbRrTvvsVUMuWGKRDIfRxvnYw9vcXH6_4N1mhWBT80UqlMaPfEVuvDPXc2cNreSszC_WMvAPetxPp9n-ow4jdGqupI2XOomZPga9LHuqttjSK9BCdQUefjB31TiCjDz5S-j3cJBuaLIh-XTN7COlPB_kj-6bsoKCLDnnSugrUS02yXqSIIipMz5SnQd2WB_XbQ3SMyNnH5GGPhNPxw
    print(String(decoding: credential.authorizationCode!, as: UTF8.self)) // c3f60fb4f464049c0a515b01fd8ecc1a2.0.nryv.cVszB9jLazzOyUx2ImSq1w
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
    // Handle error.
  }
}

extension SignInWithAppleDelegates: ASAuthorizationControllerPresentationContextProviding {
  func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
    return self.window
  }
}
