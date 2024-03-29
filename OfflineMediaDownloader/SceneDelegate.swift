import UIKit
import CoreData
import SwiftUI

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
  var window: UIWindow?
    
  func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
    guard let windowScene = scene as? UIWindowScene else { return }
    
    // let viewModel = FileListViewModel()
    // let fileListView = FileListView(viewModel: viewModel)
    
    let window = UIWindow(windowScene: windowScene)
    let mainView = MainView()
    window.rootViewController = UIHostingController(rootView: mainView)
    window.makeKeyAndVisible()
    self.window = window
  }
}
