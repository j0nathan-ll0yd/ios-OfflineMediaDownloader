import UIKit
import CoreData
import SwiftUI

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
  var window: UIWindow?
    
  func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
    guard let windowScene = scene as? UIWindowScene else { return }
    
    let viewModel = FileListViewModel()
    let fileListView = FileListView(viewModel: viewModel)
    
    let window = UIWindow(windowScene: windowScene)
    let loginView = LoginView(window:window)
    window.rootViewController = UIHostingController(rootView: loginView)
    window.makeKeyAndVisible()
    self.window = window
  }
}
