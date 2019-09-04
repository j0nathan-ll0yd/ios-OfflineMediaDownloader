//
//  Singleton.swift
//  Sandbox
//
//  Created by Jonathan Lloyd on 9/2/19.
//  Copyright © 2019 Jonathan Lloyd. All rights reserved.
//

import Foundation

final class Singleton: NSObject {
    
    static let backgroundConfiguration = URLSessionConfiguration.background(withIdentifier: "\(Bundle.main.bundleIdentifier!).background")
    
}
