import Foundation

// Ref: https://stackoverflow.com/a/44986877/7050213
extension String {
  var youtubeID: String? {
    let pattern = "((?<=(v|V)/)|(?<=be/)|(?<=(\\?|\\&)v=)|(?<=embed/))([\\w-]++)"
    let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
    let range = NSRange(location: 0, length: count)
    guard let result = regex?.firstMatch(in: self, range: range) else {
        return nil
    }
    return (self as NSString).substring(with: result.range)
  }
}
