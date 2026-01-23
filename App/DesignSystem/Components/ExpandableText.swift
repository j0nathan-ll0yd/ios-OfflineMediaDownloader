import SwiftUI

/// Expandable text for long descriptions with clickable links
public struct ExpandableText: View {
  let text: String
  let lineLimit: Int

  @State private var isExpanded = false

  public init(_ text: String, lineLimit: Int = 3) {
    self.text = text
    self.lineLimit = lineLimit
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(attributedText)
        .font(.body)
        .foregroundStyle(.white.opacity(0.9))
        .lineLimit(isExpanded ? nil : lineLimit)
        .tint(.blue)

      Button(isExpanded ? "Show less" : "Show more") {
        withAnimation(.easeInOut(duration: 0.2)) {
          isExpanded.toggle()
        }
      }
      .font(.caption)
      .foregroundStyle(.blue)
    }
  }

  /// Converts plain text with URLs into AttributedString with clickable links
  private var attributedText: AttributedString {
    var result = AttributedString(text)

    // Pattern to match URLs
    let urlPattern = #"https?://[^\s]+"#

    guard let regex = try? NSRegularExpression(pattern: urlPattern) else {
      return result
    }

    let nsRange = NSRange(text.startIndex..., in: text)
    let matches = regex.matches(in: text, range: nsRange)

    for match in matches.reversed() {
      guard let range = Range(match.range, in: text),
            let attributedRange = Range(range, in: result),
            let url = URL(string: String(text[range])) else {
        continue
      }
      result[attributedRange].link = url
      result[attributedRange].foregroundColor = .blue
    }

    return result
  }
}
