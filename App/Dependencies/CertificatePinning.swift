import Foundation
import Security
import CryptoKit

/// Certificate pinning configuration for SSL/TLS security
/// This implementation pins to Amazon's root CA for AWS API Gateway connections
enum CertificatePinning {
  /// SHA256 hashes of trusted public keys for certificate pinning
  /// These are the public key hashes for Amazon Root CA certificates
  /// Used by AWS API Gateway and other AWS services
  ///
  /// To update these hashes, run:
  /// ```
  /// openssl s_client -connect api.example.com:443 -showcerts 2>/dev/null | \
  ///   openssl x509 -pubkey -noout | \
  ///   openssl pkey -pubin -outform DER | \
  ///   openssl dgst -sha256 -binary | base64
  /// ```
  static let pinnedPublicKeyHashes: Set<String> = [
    // Amazon Root CA 1 - RSA 2048
    "++MBgDH5WGvL9Bcn5Be30cRcL0f5O+NyoXuWtQdX1aI=",
    // Amazon Root CA 2 - RSA 4096
    "f0KW/FtqTjs108NpYj42SrGvOB2PpxIVM8nWxjPqJGE=",
    // Amazon Root CA 3 - EC P256
    "NqvDJlas/GRcYbcWE8S/IceH9cq77kg0jVhZeAPXq8k=",
    // Amazon Root CA 4 - EC P384
    "9+ze1cZgR9KO1kZrVDxA4HQ6voHRCSVNz4RdTCx4U8U=",
    // Starfield Services Root CA (legacy, used by some AWS regions)
    "KwccWaCgrnaw6tsrrSO61FgLacNgG2MMLq8GE6+oP5I="
  ]

  /// Validates whether a certificate chain contains a pinned public key
  /// - Parameter serverTrust: The server's certificate trust object
  /// - Returns: True if the certificate chain contains a trusted pinned key
  static func validate(serverTrust: SecTrust) -> Bool {
    // Get the certificate chain
    guard let certificateChain = SecTrustCopyCertificateChain(serverTrust) as? [SecCertificate] else {
      print("🔒 Certificate pinning: Failed to get certificate chain")
      return false
    }

    // Check each certificate in the chain for a matching public key hash
    for certificate in certificateChain {
      if let publicKey = SecCertificateCopyKey(certificate),
         let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, nil) as? Data {
        // Calculate SHA256 hash of the public key
        let hash = SHA256.hash(data: publicKeyData)
        let hashBase64 = Data(hash).base64EncodedString()

        if pinnedPublicKeyHashes.contains(hashBase64) {
          print("🔒 Certificate pinning: Matched trusted public key")
          return true
        }
      }
    }

    print("🔒 Certificate pinning: No matching public key found in chain")
    return false
  }
}

/// URLSession delegate that implements certificate pinning
final class PinningURLSessionDelegate: NSObject, URLSessionDelegate {
  /// Whether to enforce pinning (reject connections with invalid pins)
  /// Set to false during development if needed
  let enforcesPinning: Bool

  init(enforcesPinning: Bool = true) {
    self.enforcesPinning = enforcesPinning
  }

  func urlSession(
    _ session: URLSession,
    didReceive challenge: URLAuthenticationChallenge,
    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
  ) {
    // Only handle server trust challenges
    guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
          let serverTrust = challenge.protectionSpace.serverTrust else {
      completionHandler(.performDefaultHandling, nil)
      return
    }

    // First, perform standard trust evaluation
    var error: CFError?
    let trustValid = SecTrustEvaluateWithError(serverTrust, &error)

    guard trustValid else {
      print("🔒 Certificate validation failed: \(error?.localizedDescription ?? "Unknown error")")
      completionHandler(.cancelAuthenticationChallenge, nil)
      return
    }

    // Then, validate our pins
    let pinValid = CertificatePinning.validate(serverTrust: serverTrust)

    if pinValid {
      completionHandler(.useCredential, URLCredential(trust: serverTrust))
    } else if enforcesPinning {
      print("🔒 Certificate pinning failed - connection rejected")
      completionHandler(.cancelAuthenticationChallenge, nil)
    } else {
      // Development mode: log warning but allow connection
      print("⚠️ Certificate pinning failed but enforcement is disabled")
      completionHandler(.useCredential, URLCredential(trust: serverTrust))
    }
  }
}

/// Creates a URLSession configured with certificate pinning
/// - Parameter enforcesPinning: Whether to reject connections with invalid pins
/// - Returns: A URLSession configured for certificate pinning
func makePinnedURLSession(enforcesPinning: Bool = true) -> URLSession {
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
