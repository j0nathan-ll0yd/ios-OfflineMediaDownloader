import SwiftUI

struct FileList {
  var contents: [File]
  var keyCount: Int
  
  enum CodingKeys: String, CodingKey {
    case contents = "contents"
    case keyCount = "keyCount"
  }
}

extension FileList: Decodable {
  init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    contents = try values.decode([File].self, forKey: .contents)
    keyCount = try values.decode(Int.self, forKey: .keyCount)
  }
}
