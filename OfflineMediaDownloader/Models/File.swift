import SwiftUI
import Foundation
import CoreData

extension CodingUserInfoKey {
  static let context = CodingUserInfoKey(rawValue: "context")
}

// https://www.codementor.io/@francofantillo/coredata-and-data-persistence-in-ios-uapgfgbxn
// https://medium.com/@pratheeshdhayadev/codable-nsmanagedobject-coredata-e9f42670a441
public class File: NSManagedObject, Identifiable, Codable {
  enum CodingKeys: String, CodingKey {
    case key, publishDate, size, url
  }
  
  @NSManaged public var key: String
  @NSManaged public var publishDate: Date?
  @NSManaged public var size: NSNumber?
  @NSManaged public var url: URL?
  
  var relativeDate: String {
    let formatter = DateFormatter.relativeDate
    return formatter.string(from: self.publishDate!)
  }
  
  public required convenience init(from decoder: Decoder) throws {
    guard let context = decoder.userInfo[CodingUserInfoKey.context!] as? NSManagedObjectContext else { fatalError() }
    guard let entity = NSEntityDescription.entity(forEntityName: "File", in: context) else { fatalError() }

    self.init(entity: entity, insertInto: context)
    
    let values = try decoder.container(keyedBy: CodingKeys.self)
    key = try values.decode(String.self, forKey: .key)
    let sizeInteger = try values.decode(Int.self, forKey: .size)
    size = NSNumber(integerLiteral: sizeInteger)
    
    let urlString = try values.decode(String.self, forKey: .url)
    if let url = URL(string: urlString) {
      self.url = url
    } else {
      throw DecodingError.dataCorruptedError(forKey: .url, in: values, debugDescription: "url is invalid")
    }
    
    let dateString = try values.decode(String.self, forKey: .publishDate)
    let formatter = DateFormatter.iso8601Full
    if let date = formatter.date(from: dateString) {
      publishDate = date
    } else {
      throw DecodingError.dataCorruptedError(forKey: .publishDate, in: values, debugDescription: ".publishDate string does not match formatter.")
    }
  }
  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(key, forKey: .key)
    try container.encode(publishDate, forKey: .publishDate)
    try container.encode(Int(truncating: size!), forKey: .size)
    try container.encode(url, forKey: .url)
  }
}

extension File {
  static func allFilesFetchRequest() -> NSFetchRequest<File> {
    let request = NSFetchRequest<File>(entityName: "File")
    request.sortDescriptors = [NSSortDescriptor(key: "publishDate", ascending: false)]
    return request
  }
}
