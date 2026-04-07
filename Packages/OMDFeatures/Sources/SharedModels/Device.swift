import Foundation

public struct Device: Equatable, Codable, Sendable {
  public let endpointArn: String

  public init(endpointArn: String) {
    self.endpointArn = endpointArn
  }
}
