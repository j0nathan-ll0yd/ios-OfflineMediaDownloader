//
//  SceneDelegate.swift
//  Sandbox
//
//  Created by Jonathan Lloyd on 9/7/19.
//  Copyright © 2019 Jonathan Lloyd. All rights reserved.
//

import UIKit
import SwiftUI

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
      
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        // Use this method to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.
        // If using a storyboard, the `window` property will automatically be initialized and attached to the scene.
        // This delegate does not imply the connecting scene or session are new (see `application:configurationForConnectingSceneSession` instead).
        
        guard let windowScene = scene as? UIWindowScene else { return }
        
        let viewModel = FileListViewModel()
        let fileListView = FileListView(viewModel: viewModel)

        // Use a UIHostingController as window root view controller
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = UIHostingController(rootView: fileListView)
        window.makeKeyAndVisible()
        self.window = window
    }
}

