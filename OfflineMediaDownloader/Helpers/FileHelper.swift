import Foundation

struct FileHelper {
  private static let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
  static func fileExists(file: File) -> Bool {
    let fileURL = FileHelper.filePath(url: file.url!)
    return FileManager.default.fileExists(atPath: fileURL.path)
  }
  static func filePath(url: URL) -> URL {
    let fileURL: URL = documentsPath.appendingPathComponent(url.lastPathComponent)
    return fileURL
  }
  static func deleteFile(file: File) -> Void {
    if FileHelper.fileExists(file: file) {
      let fileURL = FileHelper.filePath(url: file.url!)
      do {
        try FileManager.default.removeItem(atPath: fileURL.path)
      } catch (let deleteError) {
        print("Error deleting a file \(fileURL) : \(deleteError)")
      }
    }
  }
}
