import Foundation

public class Token: NSObject, Codable, NSCoding, NSSecureCoding {
  public static var supportsSecureCoding: Bool = true
  var decoded: String
  enum CodingKeys: String, CodingKey {
    case decoded
  }
  
  init(decoded: String) {
    self.decoded = decoded
  }
  
  public func encode(with coder: NSCoder) {
    coder.encode(decoded, forKey: "decoded")
  }
  
  convenience required public init?(coder: NSCoder) {
    guard let decoded = coder.decodeObject(forKey: "decoded") as? String else { fatalError("Missing 'decoded' in keychain'") }
    self.init(decoded: decoded)
  }
  
  required public init(with decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    decoded = try values.decode(String.self, forKey: .decoded)
  }
  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(decoded, forKey: .decoded)
  }
}
