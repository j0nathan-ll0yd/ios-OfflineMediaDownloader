//
//  DiagnosticViewModel.swift
//  OfflineMediaDownloader
//
//  Created by Jonathan Lloyd on 3/6/21.
//  Copyright © 2021 Jonathan Lloyd. All rights reserved.
//

import Foundation
import SwiftUI
import Combine
import AuthenticationServices

struct KeychainData: Identifiable {
  var id: String { name }
  var name: String
  var data: NSObject
}

final class DiagnosticViewModel: ObservableObject, Identifiable {
  @Published var keychainObjects: [KeychainData] = []

  init() {
    checkKeychain()
  }
  func checkKeychain() {
    do {
      print("DiagnosticViewModel.checkKeychain")
      let token = KeychainHelper.getToken()
      if token.decoded.count > 0 {
        self.keychainObjects.append(KeychainData(name: "Token", data: token))
      }
      if let userData = try KeychainHelper.getUserData() {
        self.keychainObjects.append(KeychainData(name: "UserData", data: userData))
      }
      if let deviceData =  try KeychainHelper.getDeviceData() {
        self.keychainObjects.append(KeychainData(name: "DeviceData", data: deviceData))
      }
    } catch let error {
      print("Keychain error")
      print(error.localizedDescription)
      debugPrint(error)
    }
  }
  func handleDelete(at offsets: IndexSet) {
    debugPrint("Deleting \(offsets)")
    guard let index = Array(offsets).first else { return }
    let keychainData = keychainObjects[index]
    debugPrint(keychainData)
    if (keychainData.data is Token) { KeychainHelper.deleteToken() }
    else if (keychainData.data is UserData) { KeychainHelper.deleteUserData() }
    else if (keychainData.data is DeviceData) { KeychainHelper.deleteDeviceData() }
    keychainObjects.remove(atOffsets: offsets)
  }
  func purgeAllLocalFiles() {
    let files = CoreDataHelper.getFiles()
    files.forEach { file in
      FileHelper.deleteFile(file: file)
    }
    CoreDataHelper.truncateFiles()
  }
}
