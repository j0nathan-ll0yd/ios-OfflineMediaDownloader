import Foundation

struct DeviceDataKeychain: Keychain {
  typealias DataType = DeviceData
  
  // Make sure the account name doesn't match the bundle identifier!
  var account = "\(Bundle.main.bundleIdentifier!).deviceIdentifier"
  var service = "deviceIdentifier"
}
