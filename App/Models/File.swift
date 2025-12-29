import Foundation

struct File: Equatable, Identifiable, Codable, Sendable {
  var fileId: String
  var key: String
  var publishDate: Date?
  var size: Int?
  var url: URL?
  // Additional fields from backend
  var authorName: String?
  var authorUser: String?
  var contentType: String?
  var description: String?
  var status: FileStatus?
  var title: String?

  var id: String { fileId }

  enum CodingKeys: String, CodingKey {
    case fileId, key, publishDate, size, url
    case authorName, authorUser, contentType, description, status, title
  }

  init(fileId: String, key: String, publishDate: Date? = nil, size: Int? = nil, url: URL? = nil) {
    self.fileId = fileId
    self.key = key
    self.publishDate = publishDate
    self.size = size
    self.url = url
  }

  init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    fileId = try values.decode(String.self, forKey: .fileId)
    key = try values.decode(String.self, forKey: .key)
    size = try values.decodeIfPresent(Int.self, forKey: .size)

    // URL is optional - backend may not include it
    if let urlString = try values.decodeIfPresent(String.self, forKey: .url) {
      url = URL(string: urlString)
    }

    // Parse date - try YYYYMMDD first (API), then ISO date (push notifications)
    if let dateString = try values.decodeIfPresent(String.self, forKey: .publishDate) {
      publishDate = DateFormatters.parse(dateString)
    }

    // Decode additional optional fields
    authorName = try values.decodeIfPresent(String.self, forKey: .authorName)
    authorUser = try values.decodeIfPresent(String.self, forKey: .authorUser)
    contentType = try values.decodeIfPresent(String.self, forKey: .contentType)
    description = try values.decodeIfPresent(String.self, forKey: .description)
    status = try values.decodeIfPresent(FileStatus.self, forKey: .status)
    title = try values.decodeIfPresent(String.self, forKey: .title)
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(fileId, forKey: .fileId)
    try container.encode(key, forKey: .key)
    try container.encodeIfPresent(size, forKey: .size)
    try container.encodeIfPresent(url?.absoluteString, forKey: .url)
    if let date = publishDate {
      try container.encode(DateFormatters.format(date), forKey: .publishDate)
    }
    try container.encodeIfPresent(authorName, forKey: .authorName)
    try container.encodeIfPresent(authorUser, forKey: .authorUser)
    try container.encodeIfPresent(contentType, forKey: .contentType)
    try container.encodeIfPresent(description, forKey: .description)
    try container.encodeIfPresent(status, forKey: .status)
    try container.encodeIfPresent(title, forKey: .title)
  }
}

