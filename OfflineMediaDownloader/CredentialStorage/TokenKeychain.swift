import Foundation

struct TokenKeychain: Keychain {
  typealias DataType = Token
  
  // Make sure the account name doesn't match the bundle identifier!
  var account = "\(Bundle.main.bundleIdentifier!).JWT"
  var service = "userAuthentication"
}
