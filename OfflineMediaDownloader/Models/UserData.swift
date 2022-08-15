import Foundation

public class UserData: NSObject, Codable, NSCoding, NSSecureCoding {
  public static var supportsSecureCoding: Bool = true
  var email: String
  var firstName: String
  var lastName: String
  var identifier: String
  
  enum CodingKeys: String, CodingKey {
    case email, firstName, identifier, lastName
  }
  
  init(email: String, firstName: String, identifier: String, lastName: String) {
    self.email = email
    self.firstName = firstName
    self.identifier = identifier
    self.lastName = lastName
  }
  
  public func encode(with coder: NSCoder) {
    coder.encode(email, forKey: "email")
    coder.encode(firstName, forKey: "firstName")
    coder.encode(identifier, forKey: "identifier")
    coder.encode(lastName, forKey: "lastName")
  }
  
  convenience required public init?(coder: NSCoder) {
    guard let email = coder.decodeObject(forKey: "email") as? String else { fatalError("Missing 'email' in keychain'") }
    guard let identifier = coder.decodeObject(forKey: "identifier") as? String else { fatalError("Missing 'email' in keychain'") }
    let firstName = coder.decodeObject(forKey: "firstName") as? String ?? ""
    let lastName = coder.decodeObject(forKey: "lastName") as? String ?? ""
    self.init(email: email, firstName: firstName, identifier:identifier, lastName: lastName)
  }
  
  required public init(with decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    email = try values.decode(String.self, forKey: .email)
    firstName = try values.decode(String.self, forKey: .firstName)
    identifier = try values.decode(String.self, forKey: .identifier)
    lastName = try values.decode(String.self, forKey: .lastName)
  }
  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(email, forKey: .email)
    try container.encode(firstName, forKey: .firstName)
    try container.encode(identifier, forKey: .identifier)
    try container.encode(lastName, forKey: .lastName)
  }
}
