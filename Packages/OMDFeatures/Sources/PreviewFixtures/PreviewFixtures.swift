import Foundation
import LifegamesWidgets
import PersistenceClient
import SharedModels

/// Canonical preview data for OMD `#Preview` blocks (S98).
///
/// Every accessor decodes schema-validated fixture JSON bundled with the
/// design system (`media/*.json`, validated against
/// `packages/schemas/authored/media-*.schema.json`) and maps it to app domain
/// types. Previews reference these members instead of constructing domain
/// models inline, so preview data cannot drift from the wire data model.
public enum PreviewFixtures {
  public enum FileVariant: String {
    case downloaded = "media-file.downloaded"
    case pending = "media-file.pending"
    case longMetadata = "media-file.long-metadata"
  }

  public enum LibraryVariant: String {
    case populatedMax = "media-library.populated-max"
    case populatedMin = "media-library.populated-min"
    case empty = "media-library.empty"
  }

  public enum ProfileVariant: String {
    case standard = "media-profile.standard"
    case newUser = "media-profile.new-user"
  }

  public static func file(_ variant: FileVariant = .downloaded) -> File {
    mapFile(decode(MediaFileProps.self, name: variant.rawValue))
  }

  public static func files(_ variant: LibraryVariant = .populatedMax) -> [File] {
    decode(MediaLibraryProps.self, name: variant.rawValue).files.map(mapFile)
  }

  public static func user(_ variant: ProfileVariant = .standard) -> User {
    let user = decode(MediaProfileProps.self, name: variant.rawValue).user
    return User(
      email: user.email,
      firstName: user.firstName,
      identifier: user.identifier,
      lastName: user.lastName
    )
  }

  public static func fileMetrics(_ variant: ProfileVariant = .standard) -> FileMetrics {
    let metrics = decode(MediaProfileProps.self, name: variant.rawValue).metrics
    return FileMetrics(
      downloadCount: metrics.downloadCount,
      totalStorageBytes: Int64(metrics.totalStorageBytes),
      playCount: metrics.playCount
    )
  }

  // MARK: - Decoding

  private static func decode<T: Decodable>(_: T.Type, name: String) -> T {
    guard let data = WidgetFixtures.data(category: "media", name: name),
          let value = try? JSONDecoder().decode(T.self, from: data)
    else {
      preconditionFailure(
        "Missing or undecodable design-system fixture media/\(name).json — "
          + "regenerate with `pnpm -F @lifegames/schemas build` in design-system-Lifegames"
      )
    }
    return value
  }

  private static func mapFile(_ props: MediaFileProps) -> File {
    var file = File(
      fileId: props.fileId,
      key: props.key,
      publishDate: props.publishDate.flatMap(DateFormatters.parse),
      size: props.size,
      url: props.url.flatMap(URL.init(string:)),
      title: props.title,
      description: props.description,
      authorName: props.authorName,
      duration: props.duration,
      uploadDate: props.uploadDate,
      viewCount: props.viewCount,
      thumbnailUrl: props.thumbnailUrl
    )
    file.authorUser = props.authorUser
    file.contentType = props.contentType
    file.status = props.status.flatMap { FileStatus(rawValue: $0.rawValue) }
    return file
  }
}
