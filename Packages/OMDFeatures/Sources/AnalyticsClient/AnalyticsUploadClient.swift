import Dependencies
import DependenciesMacros
import Foundation
import NetworkSecurity
import os.log

/// Sends `/device/event` requests for `EventBuffer`.
///
/// Live, it uploads through a session that pins the API Gateway certificate chain, like
/// `ServerClient`. The test value is unimplemented: a test that reaches it without
/// injecting a client records an issue instead of reaching the network.
@DependencyClient
public struct AnalyticsUploadClient: Sendable {
  public var send: @Sendable (_ request: URLRequest) async throws -> URLResponse
}

public extension DependencyValues {
  var analyticsUploadClient: AnalyticsUploadClient {
    get { self[AnalyticsUploadClient.self] }
    set { self[AnalyticsUploadClient.self] = newValue }
  }
}

extension AnalyticsUploadClient: DependencyKey {
  public static let liveValue = AnalyticsUploadClient(
    send: { request in
      try await pinnedUploadSession.data(for: request).1
    }
  )

  public static let testValue = AnalyticsUploadClient()
}

private let pinnedUploadSession = makePinnedURLSession(enforcesPinning: true) { event in
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

private let pinningLog = OSLog(subsystem: "OfflineMediaDownloader", category: "Analytics")
