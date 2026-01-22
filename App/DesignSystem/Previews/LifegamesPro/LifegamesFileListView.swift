import SwiftUI

// MARK: - Lifegames Pro - File List View

struct LifegamesFileListView: View {
    var files: [LifegamesFileItem] = LifegamesFileItem.samples
    var isLoading: Bool = false
    var onRefresh: (() -> Void)?
    var onAddTapped: (() -> Void)?
    var onFileTapped: ((LifegamesFileItem) -> Void)?

    private let theme = DarkProfessionalTheme()

    var body: some View {
        NavigationStack {
            ZStack {
                theme.backgroundColor
                    .ignoresSafeArea()

                if isLoading && files.isEmpty {
                    loadingView
                } else if files.isEmpty {
                    emptyView
                } else {
                    fileList
                }
            }
            .navigationTitle("Files")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 16) {
                        Button(action: { onRefresh?() }) {
                            Image(systemName: "arrow.clockwise")
                                .foregroundStyle(theme.primaryColor)
                        }

                        Button(action: { onAddTapped?() }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                                .foregroundStyle(theme.primaryColor)
                        }
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(theme.primaryColor)
            Text("Loading files...")
                .font(.subheadline)
                .foregroundStyle(theme.textSecondary)
        }
    }

    // MARK: - Empty View

    private var emptyView: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(theme.primaryColor.opacity(0.15))
                    .frame(width: 100, height: 100)

                Image(systemName: "film.stack")
                    .font(.system(size: 40))
                    .foregroundStyle(theme.primaryColor)
            }

            VStack(spacing: 8) {
                Text("No files yet")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)

                Text("Tap + to add your first video")
                    .font(.subheadline)
                    .foregroundStyle(theme.textSecondary)
            }

            Button(action: { onAddTapped?() }) {
                HStack {
                    Image(systemName: "plus")
                    Text("Add Video")
                }
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(theme.primaryColor)
                .clipShape(Capsule())
            }
        }
        .padding(32)
    }

    // MARK: - File List

    private var fileList: some View {
        ScrollView {
            LazyVStack(spacing: 1) {
                ForEach(files) { file in
                    LifegamesFileCard(file: file)
                        .onTapGesture {
                            onFileTapped?(file)
                        }
                }
            }
            .padding(.vertical, 12)
        }
        .refreshable {
            onRefresh?()
        }
    }
}

// MARK: - File Card (Rich Metadata - Issue #151)

struct LifegamesFileCard: View {
    let file: LifegamesFileItem

    private let theme = DarkProfessionalTheme()
    private let thumbnailSize = CGSize(width: 120, height: 68)

    var body: some View {
        HStack(spacing: 14) {
            // Thumbnail with duration badge
            ZStack(alignment: .bottomTrailing) {
                ThumbnailImage(fileId: file.id, url: file.thumbnailUrl, size: thumbnailSize)

                if let duration = file.duration {
                    DurationBadge(seconds: duration)
                        .padding(4)
                }
            }
            .frame(width: thumbnailSize.width, height: thumbnailSize.height)
            .overlay {
                if file.state == .downloaded {
                    Image(systemName: "play.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.5), radius: 2)
                }
            }

            // File info
            VStack(alignment: .leading, spacing: 3) {
                Text(file.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                    .lineLimit(2)

                // Author with accent color
                if let author = file.author {
                    Text(author)
                        .font(.caption)
                        .foregroundStyle(Color(red: 1.0, green: 0.4, blue: 0.4))
                }

                // Views + Size
                HStack(spacing: 6) {
                    if let viewCount = file.viewCount {
                        Text(MetadataFormatters.formatViewCount(viewCount))
                    }
                    if file.viewCount != nil && file.size != nil {
                        Text("•")
                    }
                    if file.size != nil {
                        Text(file.formattedSize)
                    }
                }
                .font(.caption)
                .foregroundStyle(theme.textSecondary)

                statusText
            }

            Spacer()

            // Progress ring for downloading
            if file.isDownloading {
                glowingProgressRing
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(theme.surfaceColor)
        .overlay(
            Rectangle()
                .fill(DarkProfessionalTheme.divider)
                .frame(height: 0.5),
            alignment: .bottom
        )
    }

    @ViewBuilder
    private var statusText: some View {
        switch file.state {
        case .pending:
            Text("Processing...")
                .font(.caption2)
                .foregroundStyle(theme.warningColor)
        case .downloading:
            Text("Downloading \(Int(file.downloadProgress * 100))%")
                .font(.caption2)
                .foregroundStyle(theme.primaryColor)
                .monospacedDigit()
        case .downloaded:
            Text("Downloaded")
                .font(.caption2)
                .foregroundStyle(theme.successColor)
        case .available:
            EmptyView()
        }
    }

    private var glowingProgressRing: some View {
        ZStack {
            // Glow
            Circle()
                .fill(theme.primaryColor.opacity(0.2))
                .frame(width: 44, height: 44)
                .blur(radius: 8)

            // Track
            Circle()
                .stroke(theme.primaryColor.opacity(0.2), lineWidth: 3)
                .frame(width: 36, height: 36)

            // Progress
            Circle()
                .trim(from: 0, to: file.downloadProgress)
                .stroke(
                    LinearGradient(
                        colors: [theme.primaryColor, theme.accentColor],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .frame(width: 36, height: 36)
                .rotationEffect(.degrees(-90))

            Text("\(Int(file.downloadProgress * 100))")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
                .monospacedDigit()
        }
    }
}

// MARK: - File Item Model (Rich Metadata - Issue #151)

struct LifegamesFileItem: Identifiable {
    let id: String
    let title: String
    let author: String?
    let size: Int?
    let state: FileState
    let thumbnailUrl: URL?
    let duration: Int?
    let viewCount: Int?

    var downloadProgress: Double = 0

    enum FileState {
        case pending, downloading, downloaded, available
    }

    var isDownloading: Bool { state == .downloading }

    var formattedSize: String {
        guard let size = size else { return "" }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(size))
    }

    static let samples: [LifegamesFileItem] = [
        LifegamesFileItem(
            id: "1",
            title: "Introduction to SwiftUI",
            author: "Apple",
            size: 150_000_000,
            state: .downloaded,
            thumbnailUrl: URL(string: "https://i.ytimg.com/vi/Tn6-PIqc4UM/maxresdefault.jpg"),
            duration: 765,
            viewCount: 2_300_000
        ),
        LifegamesFileItem(
            id: "2",
            title: "Building Modern Apps with TCA",
            author: "Point-Free",
            size: 280_000_000,
            state: .downloading,
            thumbnailUrl: URL(string: "https://i.ytimg.com/vi/HXoVSbwWUIk/maxresdefault.jpg"),
            duration: 3922,
            viewCount: 890_000,
            downloadProgress: 0.65
        ),
        LifegamesFileItem(
            id: "3",
            title: "Advanced Animations",
            author: "Kavsoft",
            size: 95_000_000,
            state: .available,
            thumbnailUrl: nil,
            duration: 58,
            viewCount: 45_000
        ),
        LifegamesFileItem(
            id: "4",
            title: "Processing Video",
            author: "Upload",
            size: nil,
            state: .pending,
            thumbnailUrl: nil,
            duration: nil,
            viewCount: nil
        ),
    ]
}

// MARK: - Previews

#Preview("File List - Populated") {
    LifegamesFileListView(files: LifegamesFileItem.samples)
}

#Preview("File List - Empty") {
    LifegamesFileListView(files: [])
}

#Preview("File List - Loading") {
    LifegamesFileListView(files: [], isLoading: true)
}
