import Foundation

public struct FileList: Codable, Sendable {
  public var contents: [File]
  public var keyCount: Int

  enum CodingKeys: String, CodingKey {
    case contents
    case keyCount
  }

  public init(contents: [File], keyCount: Int) {
    self.contents = contents
    self.keyCount = keyCount
  }
}
