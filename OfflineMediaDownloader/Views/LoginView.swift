import UIKit
import SwiftUI
import AuthenticationServices

struct LoginView: View {
  @ObservedObject var loginViewModel: LoginViewModel
  @ObservedObject var mainViewModel: MainViewModel
  var buttonStatus: SignInWithAppleButton.Label = .signIn
  
  init(loginViewModel: LoginViewModel, mainViewModel: MainViewModel) {
    self.loginViewModel = loginViewModel
    self.mainViewModel = mainViewModel
    if (mainViewModel.registrationStatus == .unregistered) {
      buttonStatus = .signUp
    }
  }

  var body: some View {
    ZStack {
      yellow.edgesIgnoringSafeArea(.all)
      VStack {
        if mainViewModel.registrationStatus == .unregistered {
          RegistrationMessageView()
          Spacer().frame(height: 50)
        }
        LogoView()
        VStack {
          SignInWithAppleButton(buttonStatus,
                                onRequest: { (request) in
            request.requestedScopes = [.fullName, .email]
            request.nonce = ""
            request.state = ""
          },
                                onCompletion: loginViewModel.handleCompletion(result:))
        }
        .signInWithAppleButtonStyle(.black)
        .frame(width: 250, height: 50)
        if mainViewModel.registrationStatus == .unregistered {
          VStack {
            Button(action: { EventHelper.emit(event: RegistrationDeclined()) }) {
              Text("No thanks")
            }
          }.frame(width: 280, alignment: .center)
        }
      }
    }
  }
}

#if DEBUG
struct LoginView_Previews: PreviewProvider {
  static var previews: some View {
    LoginView(loginViewModel: LoginViewModel(), mainViewModel: MainViewModel())
  }
}
#endif
