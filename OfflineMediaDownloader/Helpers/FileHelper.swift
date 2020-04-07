import Foundation

struct FileHelper {
  private static let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
  static func fileExists(file: File) -> Bool {
    return FileManager.default.fileExists(atPath: FileHelper.filePath(url: file.fileUrl!).absoluteString)
  }
  static func filePath(url: URL) -> URL {
    return FileHelper.documentsPath.appendingPathComponent(url.lastPathComponent)
  }
  static func deleteFile(file: File) -> Void {
    if FileHelper.fileExists(file: file) {
      let location = FileHelper.filePath(url: file.fileUrl!).absoluteString
      do {
        try FileManager.default.removeItem(atPath: location)
      } catch (let deleteError) {
        print("Error deleting a file \(location) : \(deleteError)")
      }
    }
  }
}
