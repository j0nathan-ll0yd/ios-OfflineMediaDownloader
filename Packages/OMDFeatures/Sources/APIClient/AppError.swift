import Foundation
import HTTPTypes
import OpenAPIRuntime

/// Unified error type for user-facing alerts throughout the app.
/// Provides structured error handling with titles, messages, and retry capabilities.
public enum AppError: Error, Equatable {
  // MARK: - Network Errors

  /// No internet connection available
  case networkUnavailable

  /// Server returned an error with a message and optional IDs for debugging
  case serverError(message: String, requestId: String?, correlationId: String?)

  /// Authentication token is invalid or expired (with optional IDs)
  case unauthorized(requestId: String?, correlationId: String?)

  /// Request timed out
  case timeout

  // MARK: - File Errors

  /// File download failed
  case downloadFailed(fileName: String, reason: String)

  /// File deletion failed
  case deleteFailed(fileName: String)

  /// Invalid clipboard content when adding file
  case invalidClipboardUrl

  // MARK: - Authentication Errors

  /// Login failed with a reason
  case loginFailed(reason: String)

  /// Registration failed with a reason
  case registrationFailed(reason: String)

  /// Sign in with Apple returned invalid credentials
  case invalidAppleCredential

  /// User session has expired
  case sessionExpired

  // MARK: - Storage Errors

  /// Keychain operation failed
  case keychainError(operation: String)

  /// CoreData operation failed
  case storageError(operation: String)

  // MARK: - User-Facing Properties

  /// Title for alert dialog
  public var title: String {
    switch self {
    case .networkUnavailable:
      "No Connection"
    case .serverError:
      "Server Error"
    case .unauthorized, .sessionExpired:
      "Session Expired"
    case .timeout:
      "Request Timeout"
    case .downloadFailed:
      "Download Failed"
    case .deleteFailed:
      "Delete Failed"
    case .invalidClipboardUrl:
      "Invalid URL"
    case .loginFailed:
      "Login Failed"
    case .registrationFailed:
      "Registration Failed"
    case .invalidAppleCredential:
      "Sign In Failed"
    case .keychainError:
      "Security Error"
    case .storageError:
      "Storage Error"
    }
  }

  /// The request ID for server errors, useful for debugging
  public var requestId: String? {
    switch self {
    case let .serverError(_, requestId, _), let .unauthorized(requestId, _):
      requestId
    default:
      nil
    }
  }

  /// The correlation ID for request tracing
  public var correlationId: String? {
    switch self {
    case let .serverError(_, _, correlationId), let .unauthorized(_, correlationId):
      correlationId
    default:
      nil
    }
  }

  /// User-friendly message for alert dialog
  public var message: String {
    switch self {
    case .networkUnavailable:
      return "Please check your internet connection and try again."
    case let .serverError(message, requestId, correlationId):
      var result = message
      if correlationId != nil || requestId != nil {
        result += "\n"
      }
      if let correlationId {
        result += "\nCorrelation ID: \(correlationId)"
      }
      if let requestId {
        result += "\nRequest ID: \(requestId)"
      }
      return result
    case let .unauthorized(requestId, correlationId):
      var result = "Your session has expired. Please sign in again."
      if correlationId != nil || requestId != nil {
        result += "\n"
      }
      if let correlationId {
        result += "\nCorrelation ID: \(correlationId)"
      }
      if let requestId {
        result += "\nRequest ID: \(requestId)"
      }
      return result
    case .sessionExpired:
      return "Your session has expired. Please sign in again."
    case .timeout:
      return "The request took too long. Please try again."
    case let .downloadFailed(fileName, reason):
      return "Failed to download \"\(fileName)\": \(reason)"
    case let .deleteFailed(fileName):
      return "Failed to delete \"\(fileName)\". Please try again."
    case .invalidClipboardUrl:
      return "The clipboard does not contain a valid URL."
    case let .loginFailed(reason):
      return reason
    case let .registrationFailed(reason):
      return reason
    case .invalidAppleCredential:
      return "Could not verify your Apple ID credentials. Please try again."
    case let .keychainError(operation):
      return "Failed to \(operation) secure data."
    case let .storageError(operation):
      return "Failed to \(operation) local data."
    }
  }

  /// Whether this error supports a retry action
  public var isRetryable: Bool {
    switch self {
    case .networkUnavailable, .timeout, .downloadFailed, .deleteFailed:
      true
    case .serverError, .unauthorized, .sessionExpired, .invalidClipboardUrl,
         .loginFailed, .registrationFailed, .invalidAppleCredential,
         .keychainError, .storageError:
      false
    }
  }

  /// Whether this error requires re-authentication
  public var requiresReauth: Bool {
    switch self {
    case .unauthorized, .sessionExpired:
      true
    default:
      false
    }
  }
}

// MARK: - Error Conversion

public extension AppError {
  /// Creates an AppError from any Error, mapping known error types appropriately.
  /// Note: some error type checks (ServerClientError, CoreDataError, etc.) require
  /// importing the relevant modules. Features that use this should provide their own
  /// bridging via AppError.from(_:) or use the specific case constructors directly.
  static func from(_ error: Error) -> AppError {
    // Check for OpenAPI ClientError - extract requestId from response headers
    if let clientError = error as? ClientError {
      let requestId = clientError.response?.headerFields[.init("x-amzn-requestid")!]
      let message = "Server error: \(clientError.causeDescription)"
      return .serverError(message: message, requestId: requestId, correlationId: nil)
    }

    // Check for network-related NSErrors
    let nsError = error as NSError
    if nsError.domain == NSURLErrorDomain {
      switch nsError.code {
      case NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost:
        return .networkUnavailable
      case NSURLErrorTimedOut:
        return .timeout
      default:
        break
      }
    }

    // Default: use the localized description
    return .serverError(message: error.localizedDescription, requestId: nil, correlationId: nil)
  }
}

// MARK: - LocalizedError Conformance

extension AppError: LocalizedError {
  public var errorDescription: String? {
    message
  }
}
