import Foundation

struct User: Equatable, Codable, Sendable {
  let email: String
  let firstName: String
  let identifier: String
  let lastName: String
}
