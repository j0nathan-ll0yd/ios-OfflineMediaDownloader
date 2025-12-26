import Foundation
import APITypes

public enum FileStatus: String, Codable, Equatable, Sendable, CaseIterable {
    case pending = "pending"  // Push notification sends lowercase "pending"
    case queued = "Queued"
    case downloading = "Downloading"
    case downloaded = "Downloaded"
    case failed = "Failed"

    var isDownloadable: Bool { self == .downloaded }

    var displayString: String {
        switch self {
        case .pending: return "Processing..."
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

    /// Custom decoder to handle both API format (capitalized) and push notification format (lowercase)
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)

        // Try exact match first
        if let status = FileStatus(rawValue: rawValue) {
            self = status
            return
        }

        // Try case-insensitive match
        let lowercased = rawValue.lowercased()
        switch lowercased {
        case "pending":
            self = .pending
        case "queued":
            self = .queued
        case "downloading":
            self = .downloading
        case "downloaded":
            self = .downloaded
        case "failed":
            self = .failed
        default:
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Cannot initialize FileStatus from invalid String value \(rawValue)"
                )
            )
        }
    }
}
