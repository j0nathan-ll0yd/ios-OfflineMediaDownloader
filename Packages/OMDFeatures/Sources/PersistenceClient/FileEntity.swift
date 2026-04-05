@preconcurrency import CoreData

/// Manual NSManagedObject subclass for FileEntity.
/// SPM cannot compile .xcdatamodeld files, so this replaces the auto-generated class.
/// The Xcode project still uses the xcdatamodeld; this class must stay in sync with it.
@objc(FileEntity)
public class FileEntity: NSManagedObject, @unchecked Sendable {
  @NSManaged public var fileId: String?
  @NSManaged public var isDownloaded: Bool
  @NSManaged public var key: String?
  @NSManaged public var publishDate: Date?
  @NSManaged public var size: Int64
  @NSManaged public var url: String?
  @NSManaged public var authorName: String?
  @NSManaged public var authorUser: String?
  @NSManaged public var contentType: String?
  @NSManaged public var fileDescription: String?
  @NSManaged public var status: String?
  @NSManaged public var title: String?
  @NSManaged public var duration: Int64
  @NSManaged public var uploadDate: String?
  @NSManaged public var viewCount: Int64
  @NSManaged public var thumbnailUrl: String?
}

public extension FileEntity {
  @nonobjc class func fetchRequest() -> NSFetchRequest<FileEntity> {
    NSFetchRequest<FileEntity>(entityName: "FileEntity")
  }
}
