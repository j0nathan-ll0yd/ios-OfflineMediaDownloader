import SwiftUI
import ComposableArchitecture

/// Thumbnail image with disk caching and loading states
public struct ThumbnailImage: View {
  let fileId: String?
  let url: URL?
  let size: CGSize
  let cornerRadius: CGFloat

  @State private var image: UIImage?
  @State private var isLoading = false
  @State private var loadFailed = false

  @Dependency(\.thumbnailCacheClient) var thumbnailCacheClient

  public init(
    fileId: String? = nil,
    url: URL?,
    size: CGSize = CGSize(width: 120, height: 68),
    cornerRadius: CGFloat = 8
  ) {
    self.fileId = fileId
    self.url = url
    self.size = size
    self.cornerRadius = cornerRadius
  }

  public var body: some View {
    ZStack {
      if let image = image {
        Image(uiImage: image)
          .resizable()
          .aspectRatio(contentMode: .fill)
          .frame(width: size.width, height: size.height)
          .clipped()
      } else if loadFailed {
        placeholderContent(icon: "exclamationmark.triangle")
      } else if isLoading {
        placeholderContent(icon: nil)
          .overlay { ProgressView().scaleEffect(0.7) }
      } else {
        placeholderContent(icon: "film")
      }
    }
    .frame(width: size.width, height: size.height)
    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    .task(id: url) {
      await loadThumbnail()
    }
  }

  private func loadThumbnail() async {
    guard let url = url else { return }

    // Use fileId for caching if available, otherwise derive from URL
    let cacheId = fileId ?? url.lastPathComponent

    isLoading = true
    loadFailed = false

    if let cached = await thumbnailCacheClient.getThumbnail(cacheId, url) {
      image = cached
      isLoading = false
    } else {
      loadFailed = true
      isLoading = false
    }
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

// MARK: - Preview

#Preview {
  VStack(spacing: 20) {
    ThumbnailImage(
      fileId: "test",
      url: URL(string: "https://i.ytimg.com/vi/dQw4w9WgXcQ/maxresdefault.jpg")
    )

    ThumbnailImage(
      fileId: nil,
      url: nil
    )
  }
  .padding()
  .background(Color.black)
}
