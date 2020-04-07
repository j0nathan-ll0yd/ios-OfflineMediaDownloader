import SwiftUI

struct FileList {
    var contents: [File]
    var isTruncated: Bool
    var keyCount: Int
    var maxKeys: Int
    var name: String
    var prefix: String
    
    enum CodingKeys: String, CodingKey {
        case contents = "contents"
        case isTruncated = "isTruncated"
        case keyCount = "keyCount"
        case maxKeys = "maxKeys"
        case name = "name"
        case prefix = "prefix"
    }
}

extension FileList: Decodable {
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        contents = try values.decode([File].self, forKey: .contents)
        isTruncated = try values.decode(Bool.self, forKey: .isTruncated)
        keyCount = try values.decode(Int.self, forKey: .keyCount)
        maxKeys = try values.decode(Int.self, forKey: .maxKeys)
        name = try values.decode(String.self, forKey: .name)
        prefix = try values.decode(String.self, forKey: .prefix)
    }
}
