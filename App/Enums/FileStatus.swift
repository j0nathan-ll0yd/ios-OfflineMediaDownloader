import Foundation
import APITypes

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

    /// Initialize from generated API type
    init(from apiStatus: APIFileStatus) {
        switch apiStatus {
        case .Queued: self = .queued
        case .Downloading: self = .downloading
        case .Downloaded: self = .downloaded
        case .Failed: self = .failed
        }
    }
}
