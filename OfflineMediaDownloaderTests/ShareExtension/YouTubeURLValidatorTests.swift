import Foundation
@testable import OfflineMediaDownloader
import Testing

@MainActor
@Suite("YouTubeURLValidator Tests")
struct YouTubeURLValidatorTests {
  // MARK: - Valid YouTube URLs

  @Test("Standard watch URL is valid")
  func watchURL() throws {
    let url = try #require(YouTubeURLValidator.validate("https://www.youtube.com/watch?v=dQw4w9WgXcQ"))
    #expect(url.absoluteString.contains("v=dQw4w9WgXcQ"))
  }

  @Test("Short youtu.be link is valid")
  func shortLink() throws {
    let url = try #require(YouTubeURLValidator.validate("https://youtu.be/dQw4w9WgXcQ"))
    #expect(YouTubeURLValidator.isYouTubeURL(url))
  }

  @Test("Shorts URL is valid")
  func shortsURL() throws {
    let url = try #require(YouTubeURLValidator.validate("https://www.youtube.com/shorts/abc123"))
    #expect(url.path.hasPrefix("/shorts/"))
  }

  @Test("Live URL is valid")
  func liveURL() throws {
    let url = try #require(YouTubeURLValidator.validate("https://www.youtube.com/live/abc123defgh"))
    #expect(url.path.hasPrefix("/live/"))
  }

  @Test("Embed URL is valid")
  func embedURL() throws {
    let url = try #require(YouTubeURLValidator.validate("https://www.youtube.com/embed/dQw4w9WgXcQ"))
    #expect(url.path.hasPrefix("/embed/"))
  }

  @Test("Mobile m.youtube.com URL is valid")
  func mobileURL() throws {
    let url = try #require(YouTubeURLValidator.validate("https://m.youtube.com/watch?v=dQw4w9WgXcQ"))
    #expect(YouTubeURLValidator.isYouTubeURL(url))
  }

  @Test("music.youtube.com URL is valid")
  func musicURL() throws {
    let url = try #require(YouTubeURLValidator.validate("https://music.youtube.com/watch?v=dQw4w9WgXcQ"))
    #expect(YouTubeURLValidator.isYouTubeURL(url))
  }

  @Test("URL with timestamp is valid and preserves t param")
  func urlWithTimestamp() throws {
    let url = try #require(YouTubeURLValidator.validate("https://www.youtube.com/watch?v=dQw4w9WgXcQ&t=120"))
    let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
    let tParam = components.queryItems?.first(where: { $0.name == "t" })
    #expect(tParam?.value == "120")
  }

  @Test("URL with playlist is valid and preserves list param")
  func urlWithPlaylist() throws {
    let url = try #require(YouTubeURLValidator.validate("https://www.youtube.com/watch?v=dQw4w9WgXcQ&list=PLxxx"))
    let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
    let listParam = components.queryItems?.first(where: { $0.name == "list" })
    #expect(listParam?.value == "PLxxx")
  }

  // MARK: - Tracking Param Stripping

  @Test("Tracking si param is stripped")
  func trackingParamStripped() throws {
    let url = try #require(YouTubeURLValidator.validate("https://youtu.be/dQw4w9WgXcQ?si=abc123tracking"))
    let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
    let siParam = components.queryItems?.first(where: { $0.name == "si" })
    #expect(siParam == nil)
  }

  @Test("Essential v param kept while tracking param stripped")
  func essentialParamKeptTrackingStripped() throws {
    let url = try #require(YouTubeURLValidator.validate("https://www.youtube.com/watch?v=dQw4w9WgXcQ&si=tracking&feature=share"))
    let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
    let vParam = components.queryItems?.first(where: { $0.name == "v" })
    let siParam = components.queryItems?.first(where: { $0.name == "si" })
    let featureParam = components.queryItems?.first(where: { $0.name == "feature" })
    #expect(vParam?.value == "dQw4w9WgXcQ")
    #expect(siParam == nil)
    #expect(featureParam == nil)
  }

  // MARK: - Invalid URLs

  @Test("Non-YouTube domain returns nil")
  func nonYouTubeDomain() {
    let result = YouTubeURLValidator.validate("https://vimeo.com/123456789")
    #expect(result == nil)
  }

  @Test("Empty string returns nil")
  func emptyString() {
    let result = YouTubeURLValidator.validate("")
    #expect(result == nil)
  }

  @Test("Malformed URL returns nil")
  func malformedURL() {
    let result = YouTubeURLValidator.validate("not a url at all !!!")
    #expect(result == nil)
  }

  @Test("YouTube homepage without video path returns nil")
  func youtubeHomepage() {
    let result = YouTubeURLValidator.validate("https://www.youtube.com/")
    #expect(result == nil)
  }

  // MARK: - Plain Text Extraction

  @Test("Extracts YouTube URL from plain text with title prefix")
  func extractFromPlainText() throws {
    let text = "Check this out https://youtu.be/dQw4w9WgXcQ"
    let url = try #require(YouTubeURLValidator.extractURL(from: text))
    #expect(YouTubeURLValidator.isYouTubeURL(url))
  }

  @Test("Extracts URL from YouTube app share format")
  func extractFromYouTubeAppShare() throws {
    let text = "Never Gonna Give You Up - https://youtu.be/dQw4w9WgXcQ"
    let url = try #require(YouTubeURLValidator.extractURL(from: text))
    #expect(url.host == "youtu.be")
  }

  @Test("Returns nil when no YouTube URL in text")
  func noYouTubeURLInText() {
    let text = "Check out this cool article at https://example.com/article"
    let result = YouTubeURLValidator.extractURL(from: text)
    #expect(result == nil)
  }

  // MARK: - isYouTubeURL

  @Test("isYouTubeURL returns true for supported hosts")
  func isYouTubeURLSupportedHosts() throws {
    let hosts = [
      "https://youtube.com/watch?v=abc",
      "https://www.youtube.com/watch?v=abc",
      "https://m.youtube.com/watch?v=abc",
      "https://music.youtube.com/watch?v=abc",
      "https://youtu.be/abc",
    ]
    for urlString in hosts {
      let url = try #require(URL(string: urlString))
      #expect(YouTubeURLValidator.isYouTubeURL(url), "Expected \(urlString) to be recognized as YouTube URL")
    }
  }

  @Test("isYouTubeURL returns false for non-YouTube hosts")
  func isYouTubeURLNonYouTube() throws {
    let url = try #require(URL(string: "https://vimeo.com/123"))
    #expect(!YouTubeURLValidator.isYouTubeURL(url))
  }
}
