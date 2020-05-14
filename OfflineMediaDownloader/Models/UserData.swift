import Foundation

public class UserData: NSObject, Codable, NSCoding, NSSecureCoding {
  public static var supportsSecureCoding: Bool = true
  var email: String
  var identifier: String
  enum CodingKeys: String, CodingKey {
    case email, identifier
  }
  
  init(email: String, identifier: String) {
    self.email = email
    self.identifier = identifier
  }
  
  public func encode(with coder: NSCoder) {
    coder.encode(email, forKey: "email")
    coder.encode(identifier, forKey: "identifier")
  }
  
  convenience required public init?(coder: NSCoder) {
    guard let email = coder.decodeObject(forKey: "email") as? String else { return nil }
    guard let identifier = coder.decodeObject(forKey: "identifier") as? String else { return nil }
    self.init(email: email, identifier:identifier)
  }
  
  required public init(with decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    email = try values.decode(String.self, forKey: .email)
    identifier = try values.decode(String.self, forKey: .identifier)
  }
  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(email, forKey: .email)
    try container.encode(identifier, forKey: .identifier)
  }
}
