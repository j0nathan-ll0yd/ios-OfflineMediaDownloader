import Foundation

struct TestHelper {
  static func getDefaultFile() -> File? {
    let json = """
    {
      key = "default-file.mp4";
      publishDate = "2021-02-21 05:27:51 +0000";
      size = 436743;
      url = "https://lifegames-media-downloader-files.s3.amazonaws.com/default-file.mp4";
    }
    """.data(using: .utf8)!
    do {
      let decoder = JSONDecoder()
      let file = try decoder.decode(File.self, from: json)
      return file
    } catch _ {
      print("Error JSONING")
    }
    return nil
  }
}
