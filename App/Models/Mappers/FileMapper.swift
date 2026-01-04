import Foundation
import CoreData
import APITypes

/// FileMapper handles conversion between different representations of File data.
/// This keeps the domain File model clean and independent of infrastructure concerns.
enum FileMapper {
  
  // MARK: - CoreData Mapping
  
  /// Convert a CoreData FileEntity to domain File model
  static func fromEntity(_ entity: FileEntity) -> File {
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
      title: entity.title
    )
  }
  
  /// Convert domain File to CoreData FileEntity (upsert)
  static func toEntity(_ file: File, in context: NSManagedObjectContext) -> FileEntity {
    // Try to find existing entity with same fileId
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
    
    return entity
  }
  
  // MARK: - API Type Mapping
  
  /// Convert generated API type to domain File model
  static func fromAPI(_ api: APIFile) -> File {
    let publishDate: Date? = api.publishDate.flatMap { DateFormatters.parse($0) }
    
    let status: FileStatus?
    // The generator wraps allOf references in a payload struct with value1
    if let apiStatus = api.status?.value1 {
      status = FileStatus(from: apiStatus)
    } else {
      status = nil
    }
    
    return File(
      fileId: api.fileId,
      key: api.key ?? "",
      publishDate: publishDate,
      size: api.size.map { Int($0) },
      url: api.url.flatMap { URL(string: $0) }
    ).with(
      authorName: api.authorName,
      authorUser: api.authorUser,
      contentType: api.contentType,
      description: api.description,
      status: status,
      title: api.title
    )
  }
}

// MARK: - File Extension for Builder Pattern

extension File {
  /// Builder-style method to set optional properties
  func with(
    authorName: String? = nil,
    authorUser: String? = nil,
    contentType: String? = nil,
    description: String? = nil,
    status: FileStatus? = nil,
    title: String? = nil
  ) -> File {
    var copy = self
    if let authorName = authorName { copy.authorName = authorName }
    if let authorUser = authorUser { copy.authorUser = authorUser }
    if let contentType = contentType { copy.contentType = contentType }
    if let description = description { copy.description = description }
    if let status = status { copy.status = status }
    if let title = title { copy.title = title }
    return copy
  }
}

