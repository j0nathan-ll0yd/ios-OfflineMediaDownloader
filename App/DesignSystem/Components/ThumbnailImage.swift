import SwiftUI

/// Thumbnail image with loading states
public struct ThumbnailImage: View {
  let url: URL?
  let size: CGSize
  let cornerRadius: CGFloat

  public init(url: URL?, size: CGSize = CGSize(width: 120, height: 68), cornerRadius: CGFloat = 8) {
    self.url = url
    self.size = size
    self.cornerRadius = cornerRadius
  }

  public var body: some View {
    ZStack {
      if let url = url {
        AsyncImage(url: url) { phase in
          switch phase {
          case .success(let image):
            image
              .resizable()
              .aspectRatio(contentMode: .fill)
              .frame(width: size.width, height: size.height)
              .clipped()
          case .failure:
            placeholderContent(icon: "exclamationmark.triangle")
          case .empty:
            placeholderContent(icon: nil)
              .overlay { ProgressView().scaleEffect(0.7) }
          @unknown default:
            placeholderContent(icon: "film")
          }
        }
      } else {
        placeholderContent(icon: "film")
      }
    }
    .frame(width: size.width, height: size.height)
    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
  }

  private func placeholderContent(icon: String?) -> some View {
    Rectangle()
      .fill(Color(white: 0.2))
      .overlay {
        if let icon = icon {
          Image(systemName: icon)
            .font(.title3)
            .foregroundStyle(.secondary)
        }
      }
  }
}
