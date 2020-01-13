//
//  SceneDelegate.swift
//  Sandbox
//
//  Created by Jonathan Lloyd on 9/7/19.
//  Copyright © 2019 Jonathan Lloyd. All rights reserved.
//

import UIKit
import CoreData
import SwiftUI

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
      
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        // Use this method to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.
        // If using a storyboard, the `window` property will automatically be initialized and attached to the scene.
        // This delegate does not imply the connecting scene or session are new (see `application:configurationForConnectingSceneSession` instead).
        
        guard let windowScene = scene as? UIWindowScene else { return }
        
        // ❇️ Get the managedObjectContext from the persistent container
        // ❇️ This assumes you've left the Core Data stack creation code within AppDelegate
        let managedObjectContext = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
        // A policy that merges conflicts between the persistent store’s version of the object and the current in-memory version by individual property, with the in-memory changes trumping external changes.
        managedObjectContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        let viewModel = FileListViewModel()
        // ❇️ Pass it to the ContentView through the
        // ❇️ managedObjectContext @Environment variable
        let fileListView = FileListView(viewModel: viewModel).environment(\.managedObjectContext, managedObjectContext)

        // Use a UIHostingController as window root view controller
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = UIHostingController(rootView: fileListView)
        window.makeKeyAndVisible()
        self.window = window
    }
}

