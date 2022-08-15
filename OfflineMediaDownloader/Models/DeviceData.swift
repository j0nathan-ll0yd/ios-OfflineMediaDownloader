import Foundation

public class DeviceData: NSObject, Codable, NSCoding, NSSecureCoding {
  public static var supportsSecureCoding: Bool = true
  var endpointArn: String
  enum CodingKeys: String, CodingKey {
    case endpointArn
  }
  
  init(endpointArn: String) {
    self.endpointArn = endpointArn
  }
  
  public func encode(with coder: NSCoder) {
    coder.encode(endpointArn, forKey: "endpointArn")
  }
  
  convenience required public init?(coder: NSCoder) {
    guard let endpointArn = coder.decodeObject(forKey: "endpointArn") as? String else { fatalError("Missing 'endpointArn' in keychain'") }
    self.init(endpointArn: endpointArn)
  }
  
  required public init(with decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    endpointArn = try values.decode(String.self, forKey: .endpointArn)
  }
  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(endpointArn, forKey: .endpointArn)
  }
}
