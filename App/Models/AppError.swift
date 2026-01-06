import Foundation
import OpenAPIRuntime
import HTTPTypes

/// Unified error type for user-facing alerts throughout the app.
/// Provides structured error handling with titles, messages, and retry capabilities.
enum AppError: Error, Equatable {

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
  var title: String {
    switch self {
    case .networkUnavailable:
      return "No Connection"
    case .serverError:
      return "Server Error"
    case .unauthorized, .sessionExpired:
      return "Session Expired"
    case .timeout:
      return "Request Timeout"
    case .downloadFailed:
      return "Download Failed"
    case .deleteFailed:
      return "Delete Failed"
    case .invalidClipboardUrl:
      return "Invalid URL"
    case .loginFailed:
      return "Login Failed"
    case .registrationFailed:
      return "Registration Failed"
    case .invalidAppleCredential:
      return "Sign In Failed"
    case .keychainError:
      return "Security Error"
    case .storageError:
      return "Storage Error"
    }
  }

  /// The request ID for server errors, useful for debugging
  var requestId: String? {
    switch self {
    case .serverError(_, let requestId, _), .unauthorized(let requestId, _):
      return requestId
    default:
      return nil
    }
  }

  /// The correlation ID for request tracing
  var correlationId: String? {
    switch self {
    case .serverError(_, _, let correlationId), .unauthorized(_, let correlationId):
      return correlationId
    default:
      return nil
    }
  }

  /// User-friendly message for alert dialog
  var message: String {
    switch self {
    case .networkUnavailable:
      return "Please check your internet connection and try again."
    case .serverError(let message, let requestId, let correlationId):
      var result = message
      if correlationId != nil || requestId != nil {
        result += "\n"
      }
      if let correlationId = correlationId {
        result += "\nCorrelation ID: \(correlationId)"
      }
      if let requestId = requestId {
        result += "\nRequest ID: \(requestId)"
      }
      return result
    case .unauthorized(let requestId, let correlationId):
      var result = "Your session has expired. Please sign in again."
      if correlationId != nil || requestId != nil {
        result += "\n"
      }
      if let correlationId = correlationId {
        result += "\nCorrelation ID: \(correlationId)"
      }
      if let requestId = requestId {
        result += "\nRequest ID: \(requestId)"
      }
      return result
    case .sessionExpired:
      return "Your session has expired. Please sign in again."
    case .timeout:
      return "The request took too long. Please try again."
    case .downloadFailed(let fileName, let reason):
      return "Failed to download \"\(fileName)\": \(reason)"
    case .deleteFailed(let fileName):
      return "Failed to delete \"\(fileName)\". Please try again."
    case .invalidClipboardUrl:
      return "The clipboard does not contain a valid URL."
    case .loginFailed(let reason):
      return reason
    case .registrationFailed(let reason):
      return reason
    case .invalidAppleCredential:
      return "Could not verify your Apple ID credentials. Please try again."
    case .keychainError(let operation):
      return "Failed to \(operation) secure data."
    case .storageError(let operation):
      return "Failed to \(operation) local data."
    }
  }

  /// Whether this error supports a retry action
  var isRetryable: Bool {
    switch self {
    case .networkUnavailable, .timeout, .downloadFailed, .deleteFailed:
      return true
    case .serverError, .unauthorized, .sessionExpired, .invalidClipboardUrl,
         .loginFailed, .registrationFailed, .invalidAppleCredential,
         .keychainError, .storageError:
      return false
    }
  }

  /// Whether this error requires re-authentication
  var requiresReauth: Bool {
    switch self {
    case .unauthorized, .sessionExpired:
      return true
    default:
      return false
    }
  }
}

// MARK: - Error Conversion

extension AppError {

  /// Creates an AppError from any Error, mapping known error types appropriately
  static func from(_ error: Error) -> AppError {
    // Check for ServerClientError
    if let serverError = error as? ServerClientError {
      switch serverError {
      case .unauthorized(let requestId, let correlationId):
        return .unauthorized(requestId: requestId, correlationId: correlationId)
      case .internalServerError(let message, let requestId, let correlationId):
        return .serverError(message: message, requestId: requestId, correlationId: correlationId)
      case .badRequest(let message, let requestId, let correlationId):
        return .serverError(message: message, requestId: requestId, correlationId: correlationId)
      case .networkError(let message, let requestId, let correlationId):
        return .serverError(message: message, requestId: requestId, correlationId: correlationId)
      }
    }

    // Check for OpenAPI ClientError - extract requestId from response headers
    // Note: correlationId is tracked by the middleware, not available here
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

    // Check for CoreDataError
    if let coreDataError = error as? CoreDataError {
      switch coreDataError {
      case .fetchFailed(let message):
        return .storageError(operation: "fetch: \(message)")
      case .saveFailed(let message):
        return .storageError(operation: "save: \(message)")
      case .deleteFailed(let message):
        return .storageError(operation: "delete: \(message)")
      }
    }

    // Check for KeychainError
    if error is KeychainError {
      return .keychainError(operation: "access")
    }

    // Check for FileClientError
    if let fileError = error as? FileClientError {
      switch fileError {
      case .deletionFailed(let path):
        return .deleteFailed(fileName: URL(fileURLWithPath: path).lastPathComponent)
      case .moveFailed(let message):
        return .storageError(operation: "move file: \(message)")
      }
    }

    // Check for LoginFeatureError
    if error is LoginFeatureError {
      return .invalidAppleCredential
    }

    // Check for AuthenticationError
    if error is AuthenticationError {
      return .loginFailed(reason: "Invalid credential state")
    }

    // Default: use the localized description
    return .serverError(message: error.localizedDescription, requestId: nil, correlationId: nil)
  }
}

// MARK: - LocalizedError Conformance

extension AppError: LocalizedError {
  var errorDescription: String? {
    message
  }
}
