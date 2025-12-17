import Foundation

struct FileList: Codable, Sendable {
  var contents: [File]
  var keyCount: Int

  enum CodingKeys: String, CodingKey {
    case contents
    case keyCount
  }
}
