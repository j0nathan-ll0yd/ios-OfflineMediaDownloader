import SwiftUI
import Combine
import NotificationCenter
import AuthenticationServices

final class MainViewModel: ObservableObject, Identifiable {
  @Published var hasLoaded: Bool = false
  @Published var diagnosticMode: Bool = false
  @Published var userStatus: UserStatus = .guest
  @Published var loginStatus: LoginStatus = .unauthenticated
  @Published var registrationStatus: RegistrationStatus = .unregistered
  private var cancellableSink: Cancellable?
  
  init() {
    activate()
    determineLoginStatus()
  }
  
  func determineLoginStatus() {
    do {
      print("MainViewModel.determineLoginStatus")
      let userData = try KeychainHelper.getUserData()
      let userId = userData!.identifier
      self.registrationStatus = .registered
      
      print("MainViewModel.getCredentialState")
      let provider = ASAuthorizationAppleIDProvider()
      provider.getCredentialState(forUserID: userId) { state, error in
        switch state {
        case .authorized:
          print("Credentials are valid.")
          DispatchQueue.main.async {
            self.loginStatus = .authenticated
          }
          break
        case .revoked:
          // called when a user removes SIWA via settings
          // or if the user first downloads the App
          print("Credential revoked, log them out")
          if self.registrationStatus == .registered {
            self.userStatus = .loginRequired
          }
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
    } catch let error {
      print("Keychain error")
      print(error.localizedDescription)
      debugPrint(error)
    }
    self.hasLoaded = true
  }
  
  func activate() {
    print("MainViewModel.activate")
    cancellableSink = NotificationCenter.default
      .publisher(for: Notification.Name("com.publisher.combine"))
      .sink { notification in
        print("Received Event! \(notification)")
        let event = notification.userInfo!["event"]
        if (event is LoginComplete) {
          print("Received LoginComplete")
          DispatchQueue.main.async {
            self.loginStatus = .authenticated
            self.userStatus = .registered
          }
        }
        if (event is RegistrationComplete) {
          print("Received RegistrationComplete")
          // Purge any files that were stored prior to registration
          // This would have been at most the demo file
          CoreDataHelper.truncateFiles()
          DispatchQueue.main.async {
            self.loginStatus = .authenticated
            self.userStatus = .registered
            self.registrationStatus = .registered
          }
        }
        if (event is PromptLogin) {
          print("Received PromptLogin")
          DispatchQueue.main.async {
            self.loginStatus = .unauthenticated
            self.userStatus = .loginRequired
          }
        }
        if (event is PromptRegistration) {
          print("Received PromptRegistration")
          DispatchQueue.main.async {
            self.userStatus = .registrationRequired
          }
        }
        if (event is RegistrationDeclined) {
          print("Received RegistrationDeclined")
          DispatchQueue.main.async {
            self.userStatus = .guest
          }
        }
        if (event is ToggleDiagnosticMode) {
          print("Received ToggleDiagnosticMode")
          DispatchQueue.main.async {
            self.diagnosticMode.toggle()
          }
        }
      }
  }
}
