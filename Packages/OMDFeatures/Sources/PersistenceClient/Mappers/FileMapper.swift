import Foundation
@preconcurrency import CoreData
import SharedModels

/// FileMapper handles conversion between different representations of File data.
/// This keeps the domain File model clean and independent of infrastructure concerns.
public enum FileMapper {

  // MARK: - CoreData Mapping

  /// Convert a CoreData FileEntity to domain File model
  public static func fromEntity(_ entity: FileEntity) -> File {
    File(
      fileId: entity.fileId ?? "",
      key: entity.key ?? "",
      publishDate: entity.publishDate,
      size: entity.size == 0 ? nil : Int(entity.size),
      url: entity.url.flatMap { URL(string: $0) }
    ).with(
      authorName: entity.authorName,
      authorUser: entity.authorUser,
      contentType: entity.contentType,
      description: entity.fileDescription,
      status: entity.status.flatMap { FileStatus(rawValue: $0) },
      title: entity.title,
      duration: entity.duration == 0 ? nil : Int(entity.duration),
      uploadDate: entity.uploadDate,
      viewCount: entity.viewCount == 0 ? nil : Int(entity.viewCount),
      thumbnailUrl: entity.thumbnailUrl
    )
  }

  /// Convert domain File to CoreData FileEntity (upsert)
  public static func toEntity(_ file: File, in context: NSManagedObjectContext) -> FileEntity {
    let request = FileEntity.fetchRequest()
    request.predicate = NSPredicate(format: "fileId == %@", file.fileId)
    request.fetchLimit = 1

    let entity: FileEntity
    if let existing = try? context.fetch(request).first {
      entity = existing
    } else {
      entity = FileEntity(context: context)
    }

    entity.fileId = file.fileId
    entity.key = file.key
    entity.publishDate = file.publishDate
    entity.size = Int64(file.size ?? 0)
    entity.url = file.url?.absoluteString
    entity.authorName = file.authorName
    entity.authorUser = file.authorUser
    entity.contentType = file.contentType
    entity.fileDescription = file.description
    entity.status = file.status?.rawValue
    entity.title = file.title
    entity.duration = Int64(file.duration ?? 0)
    entity.uploadDate = file.uploadDate
    entity.viewCount = Int64(file.viewCount ?? 0)
    entity.thumbnailUrl = file.thumbnailUrl

    return entity
  }
}

// MARK: - File Extension for Builder Pattern

extension File {
  /// Builder-style method to set optional properties
  public func with(
    authorName: String? = nil,
    authorUser: String? = nil,
    contentType: String? = nil,
    description: String? = nil,
    status: FileStatus? = nil,
    title: String? = nil,
    duration: Int? = nil,
    uploadDate: String? = nil,
    viewCount: Int? = nil,
    thumbnailUrl: String? = nil
  ) -> File {
    var copy = self
    if let authorName = authorName { copy.authorName = authorName }
    if let authorUser = authorUser { copy.authorUser = authorUser }
    if let contentType = contentType { copy.contentType = contentType }
    if let description = description { copy.description = description }
    if let status = status { copy.status = status }
    if let title = title { copy.title = title }
    if let duration = duration { copy.duration = duration }
    if let uploadDate = uploadDate { copy.uploadDate = uploadDate }
    if let viewCount = viewCount { copy.viewCount = viewCount }
    if let thumbnailUrl = thumbnailUrl { copy.thumbnailUrl = thumbnailUrl }
    return copy
  }
}
