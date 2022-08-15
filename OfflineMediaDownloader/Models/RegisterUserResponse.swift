import SwiftUI

struct RegisterUserResponse: Decodable {
  var body: TokenResponse
  var requestId: String
}
