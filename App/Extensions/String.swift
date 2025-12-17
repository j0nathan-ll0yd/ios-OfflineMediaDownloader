import Foundation

// Cached regex for YouTube ID extraction (avoids repeated compilation)
private let youtubeIDRegex: NSRegularExpression? = {
  try? NSRegularExpression(
    pattern: "((?<=(v|V)/)|(?<=be/)|(?<=(\\?|\\&)v=)|(?<=embed/))([\\w-]++)",
    options: .caseInsensitive
  )
}()

// Ref: https://stackoverflow.com/a/44986877/7050213
extension String {
  var youtubeID: String? {
    let range = NSRange(location: 0, length: count)
    guard let result = youtubeIDRegex?.firstMatch(in: self, range: range) else {
        return nil
    }
    return (self as NSString).substring(with: result.range)
  }
}

extension Data {
    var prettyPrintedJSONString: NSString? { /// NSString gives us a nice sanitized debugDescription
        guard let object = try? JSONSerialization.jsonObject(with: self, options: []),
              let data = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted]),
              let prettyPrintedString = NSString(data: data, encoding: String.Encoding.utf8.rawValue) else { return nil }

        return prettyPrintedString
    }
}
