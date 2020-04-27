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
    case key, lastModified, eTag, size, storageClass, fileUrl
  }
  
  @NSManaged public var key: String
  @NSManaged public var lastModified: Date?
  @NSManaged public var eTag: String?
  @NSManaged public var size: NSNumber?
  @NSManaged public var storageClass: String?
  @NSManaged public var fileUrl: URL?
  
  var relativeDate: String {
    let formatter = DateFormatter.relativeDate
    return formatter.string(from: self.lastModified!)
  }
  
  public required convenience init(from decoder: Decoder) throws {
    guard let context = decoder.userInfo[CodingUserInfoKey.context!] as? NSManagedObjectContext else { fatalError() }
    guard let entity = NSEntityDescription.entity(forEntityName: "File", in: context) else { fatalError() }

    self.init(entity: entity, insertInto: context)
    
    let values = try decoder.container(keyedBy: CodingKeys.self)
    key = try values.decode(String.self, forKey: .key)
    eTag = try values.decode(String.self, forKey: .eTag)
    let sizeInteger = try values.decode(Int.self, forKey: .size)
    size = NSNumber(integerLiteral: sizeInteger)
    storageClass = try values.decode(String.self, forKey: .storageClass)
    
    let urlString = try values.decode(String.self, forKey: .fileUrl)
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
  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(key, forKey: .key)
    try container.encode(lastModified, forKey: .lastModified)
    try container.encode(eTag, forKey: .eTag)
    try container.encode(Int(truncating: size!), forKey: .size)
    try container.encode(storageClass, forKey: .storageClass)
    try container.encode(fileUrl, forKey: .fileUrl)
  }
}

extension File {
  static func allFilesFetchRequest() -> NSFetchRequest<File> {
    let request = NSFetchRequest<File>(entityName: "File")
    request.sortDescriptors = [NSSortDescriptor(key: "lastModified", ascending: false)]
    return request
  }
}
