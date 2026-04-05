import ComposableArchitecture
import CryptoKit
import Foundation
import LoggerClient
import Security

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

  /// Validates whether a certificate chain contains a pinned public key
  public static func validate(serverTrust: SecTrust) -> Bool {
    @Dependency(\.logger) var logger
    guard let certificateChain = SecTrustCopyCertificateChain(serverTrust) as? [SecCertificate] else {
      logger.warning(.network, "Certificate pinning: Failed to get certificate chain")
      return false
    }

    for certificate in certificateChain {
      if let publicKey = SecCertificateCopyKey(certificate),
         let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, nil) as? Data
      {
        let hash = SHA256.hash(data: publicKeyData)
        let hashBase64 = Data(hash).base64EncodedString()

        if pinnedPublicKeyHashes.contains(hashBase64) {
          logger.debug(.network, "Certificate pinning: Matched trusted public key")
          return true
        }
      }
    }

    logger.warning(.network, "Certificate pinning: No matching public key found in chain")
    return false
  }
}

/// URLSession delegate that implements certificate pinning
public final class PinningURLSessionDelegate: NSObject, URLSessionDelegate, Sendable {
  public let enforcesPinning: Bool

  public init(enforcesPinning: Bool = true) {
    self.enforcesPinning = enforcesPinning
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

    var error: CFError?
    let trustValid = SecTrustEvaluateWithError(serverTrust, &error)

    @Dependency(\.logger) var logger
    guard trustValid else {
      logger.warning(.network, "Certificate validation failed: \(error?.localizedDescription ?? "Unknown error")")
      completionHandler(.cancelAuthenticationChallenge, nil)
      return
    }

    let pinValid = CertificatePinning.validate(serverTrust: serverTrust)

    if pinValid {
      completionHandler(.useCredential, URLCredential(trust: serverTrust))
    } else if enforcesPinning {
      logger.warning(.network, "Certificate pinning failed - connection rejected")
      completionHandler(.cancelAuthenticationChallenge, nil)
    } else {
      logger.warning(.network, "Certificate pinning failed but enforcement is disabled")
      completionHandler(.useCredential, URLCredential(trust: serverTrust))
    }
  }
}

/// Creates a URLSession configured with certificate pinning
public func makePinnedURLSession(enforcesPinning: Bool = true) -> URLSession {
  let delegate = PinningURLSessionDelegate(enforcesPinning: enforcesPinning)
  let configuration = URLSessionConfiguration.default
  configuration.timeoutIntervalForRequest = 30
  configuration.timeoutIntervalForResource = 60

  return URLSession(
    configuration: configuration,
    delegate: delegate,
    delegateQueue: nil
  )
}
