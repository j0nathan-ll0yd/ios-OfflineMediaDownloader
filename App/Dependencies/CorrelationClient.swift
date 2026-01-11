import Dependencies
import DependenciesMacros
import Foundation

// MARK: - Request Record

/// A record of an API request with its correlation ID and metadata
struct RequestRecord: Equatable, Sendable, Identifiable {
  let id: UUID  // This IS the correlation ID
  let timestamp: Date
  let endpoint: String
  let method: String
  var statusCode: Int?
  var duration: TimeInterval?
  var error: String?
  var serverRequestId: String?  // The x-amzn-requestid from response

  var isCompleted: Bool { statusCode != nil || error != nil }
  var isSuccess: Bool { statusCode.map { $0 >= 200 && $0 < 300 } ?? false }
  var isError: Bool { error != nil || statusCode.map { $0 >= 400 } ?? false }
}

// MARK: - Correlation Client

/// Client for generating and tracking correlation IDs across API requests
@DependencyClient
struct CorrelationClient: Sendable {
  /// Start tracking a new request, returns the correlation ID
  var startRequest: @Sendable (_ endpoint: String, _ method: String) async -> UUID = { _, _ in UUID() }

  /// Complete a request with success
  var completeRequest: @Sendable (
    _ correlationId: UUID,
    _ statusCode: Int,
    _ duration: TimeInterval,
    _ serverRequestId: String?
  ) async -> Void = { _, _, _, _ in }

  /// Complete a request with error
  var failRequest: @Sendable (
    _ correlationId: UUID,
    _ error: String,
    _ duration: TimeInterval
  ) async -> Void = { _, _, _ in }

  /// Get the most recent request record
  var getMostRecent: @Sendable () async -> RequestRecord? = { nil }

  /// Get recent request history (most recent first)
  var getRecentRequests: @Sendable (_ count: Int) async -> [RequestRecord] = { _ in [] }

  /// Clear all request history
  var clearHistory: @Sendable () async -> Void = {}
}

// MARK: - Live Implementation

extension CorrelationClient: DependencyKey {
  static let liveValue: CorrelationClient = {
    let storage = RequestStorage()

    return CorrelationClient(
      startRequest: { endpoint, method in
        await storage.start(endpoint: endpoint, method: method)
      },
      completeRequest: { correlationId, statusCode, duration, serverRequestId in
        await storage.complete(
          id: correlationId,
          statusCode: statusCode,
          duration: duration,
          serverRequestId: serverRequestId
        )
      },
      failRequest: { correlationId, error, duration in
        await storage.fail(id: correlationId, error: error, duration: duration)
      },
      getMostRecent: {
        await storage.getMostRecent()
      },
      getRecentRequests: { count in
        await storage.getRecent(count)
      },
      clearHistory: {
        await storage.clear()
      }
    )
  }()

  static let testValue = CorrelationClient()
}

extension DependencyValues {
  var correlationClient: CorrelationClient {
    get { self[CorrelationClient.self] }
    set { self[CorrelationClient.self] = newValue }
  }
}

// MARK: - Storage

/// Thread-safe actor for storing request records
private actor RequestStorage {
  private var records: [UUID: RequestRecord] = [:]
  private var orderedIds: [UUID] = []
  private let maxRecords = 100

  func start(endpoint: String, method: String) -> UUID {
    let id = UUID()
    let record = RequestRecord(
      id: id,
      timestamp: Date(),
      endpoint: endpoint,
      method: method
    )
    records[id] = record
    orderedIds.append(id)

    // Trim old records if over limit
    if orderedIds.count > maxRecords {
      let toRemove = orderedIds.removeFirst()
      records.removeValue(forKey: toRemove)
    }

    return id
  }

  func complete(id: UUID, statusCode: Int, duration: TimeInterval, serverRequestId: String?) {
    guard var record = records[id] else { return }
    record.statusCode = statusCode
    record.duration = duration
    record.serverRequestId = serverRequestId
    records[id] = record
  }

  func fail(id: UUID, error: String, duration: TimeInterval) {
    guard var record = records[id] else { return }
    record.error = error
    record.duration = duration
    records[id] = record
  }

  func getMostRecent() -> RequestRecord? {
    orderedIds.last.flatMap { records[$0] }
  }

  func getRecent(_ count: Int) -> [RequestRecord] {
    // Return most recent first
    orderedIds.suffix(count).reversed().compactMap { records[$0] }
  }

  func clear() {
    records.removeAll()
    orderedIds.removeAll()
  }
}
