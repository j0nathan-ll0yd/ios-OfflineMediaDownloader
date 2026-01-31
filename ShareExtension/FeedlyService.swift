import Foundation
import Valet

enum FeedlyServiceError: Error, LocalizedError {
    case notAuthenticated
    case invalidURL
    case notYouTubeURL
    case networkError(String)
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Please log in to the main app first"
        case .invalidURL:
            return "Invalid URL"
        case .notYouTubeURL:
            return "Only YouTube URLs are supported"
        case .networkError(let message):
            return message
        case .serverError(let message):
            return message
        }
    }
}

actor FeedlyService {
    private let sharedGroupIdentifier = SharedGroupIdentifier(
        appIDPrefix: "P328YB6M54",
        nonEmptyGroup: "group.lifegames.OfflineMediaDownloader"
    )!

    private var keychain: Valet {
        Valet.sharedGroupValet(with: sharedGroupIdentifier, accessibility: .whenUnlocked)
    }

    private var basePath: String {
        Bundle.main.infoDictionary?["MEDIA_DOWNLOADER_BASE_PATH"] as? String ?? ""
    }

    private var apiKey: String {
        Bundle.main.infoDictionary?["MEDIA_DOWNLOADER_API_KEY"] as? String ?? ""
    }

    func sendToFeedly(url: URL) async throws {
        // Validate YouTube URL
        guard YouTubeURLValidator.isYouTubeURL(url) else {
            throw FeedlyServiceError.notYouTubeURL
        }

        // Get JWT token from shared keychain
        guard let token = try? keychain.string(forKey: "jwtToken") else {
            throw FeedlyServiceError.notAuthenticated
        }

        // Build request
        guard let baseURL = URL(string: basePath) else {
            throw FeedlyServiceError.networkError("Invalid base URL configuration")
        }
        let endpoint = baseURL.appendingPathComponent("feedly")
        guard var urlComponents = URLComponents(url: endpoint, resolvingAgainstBaseURL: false) else {
            throw FeedlyServiceError.networkError("Failed to build request URL")
        }
        urlComponents.queryItems = [URLQueryItem(name: "ApiKey", value: apiKey)]

        guard let requestURL = urlComponents.url else {
            throw FeedlyServiceError.networkError("Failed to build request URL")
        }

        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")

        let body: [String: Any] = [
            "articleTitle": "Shared from YouTube",
            "articleURL": url.absoluteString
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        // Send request
        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw FeedlyServiceError.networkError("Invalid response")
        }

        switch httpResponse.statusCode {
        case 200, 202:
            return // Success
        case 401, 403:
            throw FeedlyServiceError.notAuthenticated
        case 400..<500:
            throw FeedlyServiceError.networkError("Bad request: \(httpResponse.statusCode)")
        default:
            throw FeedlyServiceError.serverError("Server error: \(httpResponse.statusCode)")
        }
    }
}
