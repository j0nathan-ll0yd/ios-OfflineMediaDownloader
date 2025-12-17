import Foundation

public enum FileStatus: String, Codable, Equatable, Sendable, CaseIterable {
    case queued = "Queued"
    case downloading = "Downloading"
    case downloaded = "Downloaded"
    case failed = "Failed"

    var isDownloadable: Bool { self == .downloaded }

    var displayString: String {
        switch self {
        case .queued: return "Queued"
        case .downloading: return "Downloading..."
        case .downloaded: return "Ready"
        case .failed: return "Failed"
        }
    }
}
