import SwiftUI

struct LoginUserResponse: Decodable {
  var body: TokenResponse?
  var error: ErrorDetail?
  var requestId: String
}
