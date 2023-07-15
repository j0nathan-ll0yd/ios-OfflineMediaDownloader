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
      ProgressView().progressViewStyle(CircularProgressViewStyle())
    }
    else if mainViewModel.userStatus == .loginRequired || mainViewModel.userStatus == .registrationRequired {
      LoginView(
        loginViewModel: loginViewModel,
        mainViewModel: mainViewModel
      )
    }
    else {
      TabView {
        FileListView(
          fileListViewModel: fileListViewModel,
          mainViewModel: mainViewModel
        ).onAppear {
          fileListViewModel.searchLocal()
        }.tabItem {
          Label("Files", systemImage: "list.bullet")
        }
        DiagnosticView().tabItem {
          Label("Account", systemImage: "person.crop.circle")
        }
      }
    }
  }
}

#if DEBUG
struct MainView_Previews: PreviewProvider {
  static var previews: some View {
    MainView()
  }
}
#endif
