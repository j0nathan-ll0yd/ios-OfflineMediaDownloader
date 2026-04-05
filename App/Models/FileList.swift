import Foundation

struct FileList: Codable {
  var contents: [File]
  var keyCount: Int

  enum CodingKeys: String, CodingKey {
    case contents
    case keyCount
  }
}
