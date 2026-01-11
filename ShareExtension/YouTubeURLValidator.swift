import Foundation

enum YouTubeURLValidator {
    private static let youtubeIDRegex: NSRegularExpression? = {
        try? NSRegularExpression(
            pattern: "((?<=(v|V)/)|(?<=be/)|(?<=(\\?|\\&)v=)|(?<=embed/))([\\w-]++)",
            options: .caseInsensitive
        )
    }()

    static func isYouTubeURL(_ url: URL) -> Bool {
        let host = url.host?.lowercased() ?? ""
        let validHosts = ["youtube.com", "www.youtube.com", "m.youtube.com", "youtu.be"]

        guard validHosts.contains(host) else { return false }

        // For youtu.be, path should have video ID
        if host == "youtu.be" {
            return url.path.count > 1
        }

        // For youtube.com, check for v= parameter or /v/ path
        let urlString = url.absoluteString
        let range = NSRange(location: 0, length: urlString.count)
        return youtubeIDRegex?.firstMatch(in: urlString, range: range) != nil
    }

    static func extractVideoID(from url: URL) -> String? {
        let urlString = url.absoluteString
        let range = NSRange(location: 0, length: urlString.count)
        guard let result = youtubeIDRegex?.firstMatch(in: urlString, range: range) else {
            return nil
        }
        return (urlString as NSString).substring(with: result.range)
    }
}
