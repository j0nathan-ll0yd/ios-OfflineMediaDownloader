import Foundation

public struct User: Equatable, Codable, Sendable {
  public let email: String
  public let firstName: String
  public let identifier: String
  public let lastName: String

  public init(email: String, firstName: String, identifier: String, lastName: String) {
    self.email = email
    self.firstName = firstName
    self.identifier = identifier
    self.lastName = lastName
  }
}
