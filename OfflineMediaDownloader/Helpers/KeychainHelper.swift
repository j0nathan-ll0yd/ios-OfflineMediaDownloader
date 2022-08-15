import Foundation
import CoreData
import UIKit

struct KeychainHelper {
  static func storeToken(token: Token) -> Void {
    print("KeychainHelper.storeToken")
    let keychain = TokenKeychain()
    do {
      try keychain.store(token)
    } catch let error as NSError {
      print(error.localizedDescription)
      debugPrint(error)
    }
  }
  static func getToken() -> Token {
    do {
      print("KeychainHelper.getToken")
      let keychain = TokenKeychain()
      let token = try keychain.retrieve()
      debugPrint(token)
      return token
    } catch let error {
      // occurs when keychain doesn't exist
      if error is KeychainError {
        switch error as! KeychainError {
        case .notFound:
          print("notFound")
          break
        case .secCallFailed(_):
          print("secCallFailed")
          break
        case .badData:
          print("badData")
          break
        case .archiveFailure(_):
          print("archiveFailure")
          break
        }
      }
    }
    return Token(decoded: "")
  }
  static func deleteToken() -> Void {
    do {
      print("KeychainHelper.deleteToken")
      let keychain = TokenKeychain()
      try keychain.remove()
    } catch let error {
      print(error.localizedDescription)
      debugPrint(error)
    }
  }
  static func getUserData() throws -> UserData? {
    do {
      print("KeychainHelper.getUserData")
      let keychain = UserDataKeychain()
      return try keychain.retrieve()
    } catch let error {
      print(error.localizedDescription)
      debugPrint(error)
      throw error
    }
  }
  static func deleteUserData() -> Void {
    do {
      print("KeychainHelper.deleteUserData")
      let keychain = UserDataKeychain()
      try keychain.remove()
    } catch let error {
      print(error.localizedDescription)
      debugPrint(error)
    }
  }
  static func getDeviceData() throws -> DeviceData? {
    do {
      print("KeychainHelper.getDeviceData")
      let keychain = DeviceDataKeychain()
      return try keychain.retrieve()
    } catch let error {
      print(error.localizedDescription)
      debugPrint(error)
      throw error
    }
  }
  static func deleteDeviceData() -> Void {
    do {
      print("KeychainHelper.deleteDeviceData")
      let keychain = DeviceDataKeychain()
      try keychain.remove()
    } catch let error {
      print(error.localizedDescription)
      debugPrint(error)
    }
  }
  static func storeDeviceData(deviceData: DeviceData) -> Void {
    print("KeychainHelper.storeDeviceData")
    do {
      let keychain = DeviceDataKeychain()
      try keychain.store(deviceData)
    } catch let error as NSError {
      print(error.localizedDescription)
      debugPrint(error)
    }
  }
}
