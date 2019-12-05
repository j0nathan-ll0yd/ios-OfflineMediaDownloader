import SwiftUI

struct File : Identifiable {
    var id = UUID()
    var key: String
    var lastModified: Date
    var eTag: String
    var size: Int
    var storageClass: String
    var fileUrl: URL
    
    var relativeDate: String {
        let formatter = DateFormatter.relativeDate
        return formatter.string(from: self.lastModified)
    }
    
    enum CodingKeys: String, CodingKey {
        case key = "Key"
        case lastModified = "LastModified"
        case eTag = "ETag"
        case size = "Size"
        case storageClass = "StorageClass"
        case fileUrl = "FileUrl"
    }
}

extension File: Decodable {
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        key = try values.decode(String.self, forKey: .key)
        eTag = try values.decode(String.self, forKey: .eTag)
        size = try values.decode(Int.self, forKey: .size)
        storageClass = try values.decode(String.self, forKey: .storageClass)
        
        let urlString = try values.decode(String.self, forKey: .fileUrl)
        print(urlString)
        if let url = URL(string: urlString) {
            fileUrl = url
        } else {
            throw DecodingError.dataCorruptedError(forKey: .fileUrl, in: values, debugDescription: "fileUrl is invalid")
        }
        
        let dateString = try values.decode(String.self, forKey: .lastModified)
        let formatter = DateFormatter.iso8601Full
        if let date = formatter.date(from: dateString) {
            lastModified = date
        } else {
            throw DecodingError.dataCorruptedError(forKey: .lastModified, in: values, debugDescription: ".lastModified string does not match formatter.")
        }
    }
}
