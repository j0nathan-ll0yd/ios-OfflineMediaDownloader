import UIKit
import SwiftUI
import AuthenticationServices

struct MainView: View {
  @ObservedObject var fileListViewModel = FileListViewModel()
  @ObservedObject var loginViewModel = LoginViewModel()
  @ObservedObject var mainViewModel = MainViewModel()
  
  var body: some View {
    if mainViewModel.diagnosticMode == true {
      DiagnosticView()
    }
    else if mainViewModel.hasLoaded == false {
      ProgressView()
    }
    else if mainViewModel.userStatus == .loginRequired || mainViewModel.userStatus == .registrationRequired {
      LoginView(
        loginViewModel: loginViewModel,
        mainViewModel: mainViewModel
      )
    }
    else {
      FileListView(
        fileListViewModel: fileListViewModel,
        mainViewModel: mainViewModel
      ).onAppear {
        fileListViewModel.searchLocal()
        fileListViewModel.searchRemote()
      }
    }
  }
}
