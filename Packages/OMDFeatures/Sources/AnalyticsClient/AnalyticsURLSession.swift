import Dependencies
import Foundation
import NetworkSecurity
import os.log

public extension DependencyValues {
  /// The session `EventBuffer` uploads `/device/event` batches through. Live, it pins the
  /// API Gateway certificate chain like `ServerClient`.
  var analyticsURLSession: URLSession {
    get { self[AnalyticsURLSessionKey.self] }
    set { self[AnalyticsURLSessionKey.self] = newValue }
  }
}

private enum AnalyticsURLSessionKey: DependencyKey {
  static let liveValue = makePinnedURLSession(enforcesPinning: true) { event in
    switch event {
    case .pinMatched:
      return
    case let .trustEvaluationFailed(host, reason):
      // SANCTIONED-SINK: AnalyticsClient's error-path relay for upload TLS failures
      os_log("Analytics upload to %{public}@ failed trust evaluation: %{public}@", log: pinningLog, type: .error, host, reason)
    case let .pinFailed(host, outcome, enforced):
      // A pinning failure cannot be reported through analytics: the upload it would ride on is the one that failed.
      // SANCTIONED-SINK: AnalyticsClient's error-path relay for upload pinning failures
      os_log(
        "Analytics upload to %{public}@ failed certificate pinning (%{public}@, enforced: %{public}@)",
        log: pinningLog,
        type: .error,
        host,
        String(describing: outcome),
        String(enforced)
      )
    }
  }

  /// Tests must inject their own session; this one has no pinning and no network stubs.
  static let testValue = URLSession(configuration: .ephemeral)
}

private let pinningLog = OSLog(subsystem: "OfflineMediaDownloader", category: "Analytics")
