import APITypes
import Foundation
import HTTPTypes
@preconcurrency import OpenAPIRuntime
import OpenAPIURLSession
import os
import Valet

// MARK: - ShareError

enum ShareError: Error, LocalizedError {
  case notAuthenticated
  case tokenExpired
  case invalidURL
  case unauthorized
  case serverError

  var errorDescription: String? {
    switch self {
    case .notAuthenticated:
      NSLocalizedString("You must be logged in to share URLs.", comment: "Not authenticated error")
    case .tokenExpired:
      NSLocalizedString("Your session has expired. Please open the app and log in again.", comment: "Token expired error")
    case .invalidURL:
      NSLocalizedString("The URL could not be submitted.", comment: "Invalid URL error")
    case .unauthorized:
      NSLocalizedString("You are not authorized to perform this action.", comment: "Unauthorized error")
    case .serverError:
      NSLocalizedString("A server error occurred. Please try again.", comment: "Server error")
    }
  }
}

// MARK: - ShareService

enum ShareService {
  private static let logger = Logger(
    subsystem: "lifegames.OfflineMediaDownloader.ShareExtension",
    category: "ShareService"
  )

  static func submitURL(_ url: URL) async throws {
    logger.info("ShareService.submitURL called with: \(url.absoluteString)")

    // Read config from bundle
    let infoDictionary = Bundle.main.infoDictionary ?? [:]
    guard let apiKey = infoDictionary["MEDIA_DOWNLOADER_API_KEY"] as? String, !apiKey.isEmpty else {
      logger.error("ShareService: MEDIA_DOWNLOADER_API_KEY not found in bundle")
      throw ShareError.invalidURL
    }
    guard let basePath = infoDictionary["MEDIA_DOWNLOADER_BASE_PATH"] as? String,
          let serverURL = URL(string: basePath)
    else {
      logger.error("ShareService: MEDIA_DOWNLOADER_BASE_PATH not found or invalid in bundle")
      throw ShareError.invalidURL
    }

    // Read JWT from shared group Valet
    guard let groupIdentifier = SharedGroupIdentifier(groupPrefix: "group", nonEmptyGroup: "lifegames.OfflineMediaDownloader") else {
      logger.error("ShareService: invalid shared group identifier")
      throw ShareError.notAuthenticated
    }
    let sharedValet = Valet.sharedGroupValet(with: groupIdentifier, accessibility: .afterFirstUnlock)

    let token: String
    do {
      token = try sharedValet.string(forKey: "jwtToken")
    } catch {
      logger.error("ShareService: no JWT token in shared keychain — \(error.localizedDescription)")
      throw ShareError.notAuthenticated
    }

    // Check token expiry before making the API call
    if let expiryString = try? sharedValet.string(forKey: "jwtTokenExpiresAt"),
       let expiryInterval = Double(expiryString)
    {
      let expiryDate = Date(timeIntervalSince1970: expiryInterval)
      if expiryDate <= Date() {
        logger.warning("ShareService: JWT token is expired (expired at \(expiryDate))")
        throw ShareError.tokenExpired
      }
    }

    let client = Client(
      serverURL: serverURL,
      transport: URLSessionTransport(),
      middlewares: [
        ShareAPIKeyMiddleware(apiKey: apiKey),
        ShareAuthMiddleware(token: token),
      ]
    )

    let requestBody = Components.Schemas.Models_period_FeedlyWebhookRequest(
      articleURL: url.absoluteString
    )

    logger.info("ShareService: submitting URL to server")
    let response = try await client.postFeedlyWebhook(body: .json(requestBody))

    switch response {
    case .ok:
      logger.info("ShareService: submission succeeded (200)")
    case .accepted:
      logger.info("ShareService: submission accepted (202)")
    case .unauthorized:
      logger.warning("ShareService: unauthorized (401)")
      throw ShareError.unauthorized
    default:
      logger.error("ShareService: unexpected response")
      throw ShareError.serverError
    }
  }
}

// MARK: - Inline Middleware

/// Adds the API key as a query parameter. Must be ?ApiKey=xxx (NOT a header).
private struct ShareAPIKeyMiddleware: ClientMiddleware {
  let apiKey: String

  func intercept(
    _ request: HTTPTypes.HTTPRequest,
    body: OpenAPIRuntime.HTTPBody?,
    baseURL: URL,
    operationID _: String,
    next: (HTTPTypes.HTTPRequest, OpenAPIRuntime.HTTPBody?, URL) async throws -> (HTTPTypes.HTTPResponse, OpenAPIRuntime.HTTPBody?)
  ) async throws -> (HTTPTypes.HTTPResponse, OpenAPIRuntime.HTTPBody?) {
    var request = request
    if let currentPath = request.path {
      let separator = currentPath.contains("?") ? "&" : "?"
      request.path = "\(currentPath)\(separator)ApiKey=\(apiKey)"
    }
    return try await next(request, body, baseURL)
  }
}

/// Adds the JWT Bearer token as an Authorization header.
private struct ShareAuthMiddleware: ClientMiddleware {
  let token: String

  func intercept(
    _ request: HTTPTypes.HTTPRequest,
    body: OpenAPIRuntime.HTTPBody?,
    baseURL: URL,
    operationID _: String,
    next: (HTTPTypes.HTTPRequest, OpenAPIRuntime.HTTPBody?, URL) async throws -> (HTTPTypes.HTTPResponse, OpenAPIRuntime.HTTPBody?)
  ) async throws -> (HTTPTypes.HTTPResponse, OpenAPIRuntime.HTTPBody?) {
    var request = request
    request.headerFields[.authorization] = "Bearer \(token)"
    return try await next(request, body, baseURL)
  }
}
