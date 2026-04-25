import Foundation

enum YouTubeURLValidator {
  // MARK: - Public API

  /// Validates a string as a YouTube URL, returning a cleaned URL or nil.
  static func validate(_ input: String) -> URL? {
    guard let url = URL(string: input.trimmingCharacters(in: .whitespacesAndNewlines)) else {
      return nil
    }
    return validate(url) ? cleanURL(url) ?? url : nil
  }

  /// Validates a URL as a YouTube URL (used by ShareViewController).
  @discardableResult
  static func validate(_ url: URL) -> Bool {
    isYouTubeURL(url) && isSupportedPath(url)
  }

  /// Extracts a YouTube URL from plain text (YouTube app shares as "Title - https://youtu.be/xxx").
  static func extractURL(from text: String) -> URL? {
    let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
    let range = NSRange(text.startIndex..., in: text)
    let matches = detector?.matches(in: text, options: [], range: range) ?? []

    for match in matches {
      guard let url = match.url, isYouTubeURL(url), isSupportedPath(url) else { continue }
      return cleanURL(url) ?? url
    }
    return nil
  }

  /// Returns true if the URL's host is a supported YouTube domain.
  static func isYouTubeURL(_ url: URL) -> Bool {
    guard let host = url.host?.lowercased() else { return false }
    return supportedHosts.contains(host)
  }

  // MARK: - Private

  private static let supportedHosts: Set<String> = [
    "youtube.com",
    "www.youtube.com",
    "m.youtube.com",
    "music.youtube.com",
    "youtu.be",
  ]

  /// Returns true if the URL path matches a supported YouTube content path.
  private static func isSupportedPath(_ url: URL) -> Bool {
    guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
      return false
    }
    let host = components.host?.lowercased() ?? ""
    let path = components.path

    if host == "youtu.be" {
      // youtu.be/<videoId>
      let videoId = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
      return !videoId.isEmpty
    }

    // /watch?v=<videoId>
    if path == "/watch" {
      return components.queryItems?.contains(where: { $0.name == "v" && !($0.value ?? "").isEmpty }) ?? false
    }

    // /shorts/<videoId>, /live/<videoId>, /embed/<videoId>
    let supportedPrefixes = ["/shorts/", "/live/", "/embed/"]
    for prefix in supportedPrefixes {
      if path.hasPrefix(prefix) {
        let videoId = String(path.dropFirst(prefix.count))
        if !videoId.isEmpty { return true }
      }
    }

    return false
  }

  /// Strips tracking params (?si=, &feature=) but keeps essential params (?v=, ?t=, ?list=).
  private static func cleanURL(_ url: URL) -> URL? {
    guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
      return nil
    }
    let essentialParams: Set = ["v", "t", "list"]
    let originalItems = components.queryItems ?? []
    let filtered = originalItems.filter { essentialParams.contains($0.name) }
    components.queryItems = filtered.isEmpty ? nil : filtered
    return components.url
  }
}
