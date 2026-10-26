import CryptoKit
import Foundation
import Security

// Foundation, Security and CryptoKit only: the Notification Service Extension links this
// target, and it runs under a tight memory limit. Callers receive outcomes as
// `PinningEvent` values and log or report them with their own clients.

/// Certificate pinning configuration for SSL/TLS security
/// This implementation pins to Amazon's root CA for AWS API Gateway connections
public enum CertificatePinning {
  /// SHA256 hashes of trusted public keys for certificate pinning
  public static let pinnedPublicKeyHashes: Set<String> = [
    // Amazon Root CA 1 - computed by iOS SecKeyCopyExternalRepresentation (raw key, no ASN.1 header)
    "UAJ/9yOqq6nk4CX2QtZgDmyT6JHYlkBfihOzezH/8cs=",
    // Amazon RSA 2048 M01 - Intermediate CA (issued by Amazon Root CA 1)
    "/LWYS0bnqApLztW89p14Ilm/6JdJpH9mSOpWaxSNCL0=",
  ]

  /// The result of checking a certificate chain against `pinnedPublicKeyHashes`.
  public enum Outcome: Sendable, Equatable {
    case matched
    case noMatchingKey
    case unreadableChain
  }

  /// Checks whether a certificate chain contains a pinned public key.
  public static func evaluate(serverTrust: SecTrust) -> Outcome {
    guard let certificateChain = SecTrustCopyCertificateChain(serverTrust) as? [SecCertificate] else {
      return .unreadableChain
    }

    for certificate in certificateChain {
      if let publicKey = SecCertificateCopyKey(certificate),
         let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, nil) as? Data
      {
        let hash = SHA256.hash(data: publicKeyData)
        if pinnedPublicKeyHashes.contains(Data(hash).base64EncodedString()) {
          return .matched
        }
      }
    }
    return .noMatchingKey
  }

  /// The decision for one server-trust challenge.
  ///
  /// - Parameters:
  ///   - trustValid: the result of system trust evaluation (`SecTrustEvaluateWithError`).
  ///   - outcome: the pin check. `nil` when trust evaluation failed and the chain was not checked.
  ///   - enforcesPinning: whether a chain without a pinned key is rejected.
  /// - Returns: `.cancelAuthenticationChallenge` when trust fails, or when the pin check fails
  ///   under enforcement; otherwise `.useCredential`.
  public static func disposition(
    trustValid: Bool,
    outcome: Outcome?,
    enforcesPinning: Bool
  ) -> URLSession.AuthChallengeDisposition {
    guard trustValid, let outcome else {
      return .cancelAuthenticationChallenge
    }
    if outcome == .matched {
      return .useCredential
    }
    return enforcesPinning ? .cancelAuthenticationChallenge : .useCredential
  }
}

/// What a pinned session decided for one server-trust challenge.
public enum PinningEvent: Sendable, Equatable {
  /// System trust evaluation failed; the connection was cancelled.
  case trustEvaluationFailed(host: String, reason: String)
  /// The chain contained a pinned key; the connection proceeded.
  case pinMatched(host: String)
  /// The chain contained no pinned key. `enforced` says whether the connection was cancelled.
  case pinFailed(host: String, outcome: CertificatePinning.Outcome, enforced: Bool)
}

/// URLSession delegate that implements certificate pinning
public final class PinningURLSessionDelegate: NSObject, URLSessionDelegate, Sendable {
  public let enforcesPinning: Bool
  private let onEvent: @Sendable (PinningEvent) -> Void

  public init(enforcesPinning: Bool = true, onEvent: @escaping @Sendable (PinningEvent) -> Void) {
    self.enforcesPinning = enforcesPinning
    self.onEvent = onEvent
  }

  public func urlSession(
    _: URLSession,
    didReceive challenge: URLAuthenticationChallenge,
    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
  ) {
    guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
          let serverTrust = challenge.protectionSpace.serverTrust
    else {
      completionHandler(.performDefaultHandling, nil)
      return
    }

    let host = challenge.protectionSpace.host
    var error: CFError?
    let trustValid = SecTrustEvaluateWithError(serverTrust, &error)
    let outcome = trustValid ? CertificatePinning.evaluate(serverTrust: serverTrust) : nil

    switch outcome {
    case nil:
      onEvent(.trustEvaluationFailed(host: host, reason: error?.localizedDescription ?? "Unknown error"))
    case .matched:
      onEvent(.pinMatched(host: host))
    case let .some(outcome):
      onEvent(.pinFailed(host: host, outcome: outcome, enforced: enforcesPinning))
    }

    let disposition = CertificatePinning.disposition(trustValid: trustValid, outcome: outcome, enforcesPinning: enforcesPinning)
    completionHandler(disposition, disposition == .useCredential ? URLCredential(trust: serverTrust) : nil)
  }
}

/// Creates a URLSession configured with certificate pinning
public func makePinnedURLSession(
  enforcesPinning: Bool = true,
  onEvent: @escaping @Sendable (PinningEvent) -> Void
) -> URLSession {
  let delegate = PinningURLSessionDelegate(enforcesPinning: enforcesPinning, onEvent: onEvent)
  let configuration = URLSessionConfiguration.default
  configuration.timeoutIntervalForRequest = 30
  configuration.timeoutIntervalForResource = 60

  return URLSession(
    configuration: configuration,
    delegate: delegate,
    delegateQueue: nil
  )
}
