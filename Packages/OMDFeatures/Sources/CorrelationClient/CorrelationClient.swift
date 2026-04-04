import Dependencies
import DependenciesMacros
import Foundation

// MARK: - Request Record

/// A record of an API request with its correlation ID and metadata
public struct RequestRecord: Equatable, Sendable, Identifiable {
  public let id: UUID  // This IS the correlation ID
  public let timestamp: Date
  public let endpoint: String
  public let method: String
  public var statusCode: Int?
  public var duration: TimeInterval?
  public var error: String?
  public var serverRequestId: String?  // The x-amzn-requestid from response

  public var isCompleted: Bool { statusCode != nil || error != nil }
  public var isSuccess: Bool { statusCode.map { $0 >= 200 && $0 < 300 } ?? false }
  public var isError: Bool { error != nil || statusCode.map { $0 >= 400 } ?? false }

  public init(
    id: UUID,
    timestamp: Date,
    endpoint: String,
    method: String,
    statusCode: Int? = nil,
    duration: TimeInterval? = nil,
    error: String? = nil,
    serverRequestId: String? = nil
  ) {
    self.id = id
    self.timestamp = timestamp
    self.endpoint = endpoint
    self.method = method
    self.statusCode = statusCode
    self.duration = duration
    self.error = error
    self.serverRequestId = serverRequestId
  }
}

// MARK: - Correlation Client

/// Client for generating and tracking correlation IDs across API requests
@DependencyClient
public struct CorrelationClient: Sendable {
  /// Start tracking a new request, returns the correlation ID
  public var startRequest: @Sendable (_ endpoint: String, _ method: String) async -> UUID = { _, _ in UUID() }

  /// Complete a request with success
  public var completeRequest: @Sendable (
    _ correlationId: UUID,
    _ statusCode: Int,
    _ duration: TimeInterval,
    _ serverRequestId: String?
  ) async -> Void = { _, _, _, _ in }

  /// Complete a request with error
  public var failRequest: @Sendable (
    _ correlationId: UUID,
    _ error: String,
    _ duration: TimeInterval
  ) async -> Void = { _, _, _ in }

  /// Get the most recent request record
  public var getMostRecent: @Sendable () async -> RequestRecord? = { nil }

  /// Get recent request history (most recent first)
  public var getRecentRequests: @Sendable (_ count: Int) async -> [RequestRecord] = { _ in [] }

  /// Clear all request history
  public var clearHistory: @Sendable () async -> Void = {}
}

// MARK: - Live Implementation

extension CorrelationClient: DependencyKey {
  public static let liveValue: CorrelationClient = {
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

  public static let testValue = CorrelationClient()
}

extension DependencyValues {
  public var correlationClient: CorrelationClient {
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
