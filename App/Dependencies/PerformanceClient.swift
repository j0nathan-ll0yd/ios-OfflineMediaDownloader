import Dependencies
import DependenciesMacros
import Foundation

// MARK: - Performance Types

struct PerformanceTrace: Sendable {
  let id: UUID
  let name: String
  let startTime: Date
  var endTime: Date?
  var metadata: [String: String]

  var duration: TimeInterval? {
    guard let endTime else { return nil }
    return endTime.timeIntervalSince(startTime)
  }
}

struct PerformanceMetric: Sendable {
  let name: String
  let value: Double
  let unit: String
  let timestamp: Date
  let metadata: [String: String]?
}

// MARK: - Performance Client

@DependencyClient
struct PerformanceClient: Sendable {
  var startTrace: @Sendable (String) -> UUID = { _ in UUID() }
  var endTrace: @Sendable (UUID, [String: String]?) -> Void = { _, _ in }
  var recordMetric: @Sendable (String, Double, String, [String: String]?) -> Void = { _, _, _, _ in }
  var getActiveTraces: @Sendable () -> [PerformanceTrace] = { [] }
  var getRecentMetrics: @Sendable (Int) -> [PerformanceMetric] = { _ in [] }
}

// MARK: - Convenience Methods

extension PerformanceClient {
  /// Execute a block and automatically trace its duration
  func trace<T>(
    _ name: String,
    metadata: [String: String]? = nil,
    operation: () async throws -> T
  ) async rethrows -> T {
    let traceId = startTrace(name)
    defer { endTrace(traceId, metadata) }
    return try await operation()
  }

  /// Record a timing metric in milliseconds
  func recordTiming(_ name: String, milliseconds: Double, metadata: [String: String]? = nil) {
    recordMetric(name, milliseconds, "ms", metadata)
  }

  /// Record a count metric
  func recordCount(_ name: String, count: Int, metadata: [String: String]? = nil) {
    recordMetric(name, Double(count), "count", metadata)
  }

  /// Record a size metric in bytes
  func recordSize(_ name: String, bytes: Int64, metadata: [String: String]? = nil) {
    recordMetric(name, Double(bytes), "bytes", metadata)
  }
}

// MARK: - Live Implementation

extension PerformanceClient: DependencyKey {
  static let liveValue: PerformanceClient = {
    let storage = PerformanceStorage()

    return PerformanceClient(
      startTrace: { name in
        let trace = PerformanceTrace(
          id: UUID(),
          name: name,
          startTime: Date(),
          metadata: [:]
        )
        storage.startTrace(trace)
        return trace.id
      },
      endTrace: { id, metadata in
        if let trace = storage.endTrace(id, metadata: metadata) {
          #if DEBUG
          if let duration = trace.duration {
            let ms = duration * 1000
            print("⏱️ [\(trace.name)] \(String(format: "%.2f", ms))ms")
          }
          #endif
        }
      },
      recordMetric: { name, value, unit, metadata in
        let metric = PerformanceMetric(
          name: name,
          value: value,
          unit: unit,
          timestamp: Date(),
          metadata: metadata
        )
        storage.recordMetric(metric)
        #if DEBUG
        print("📊 [\(name)] \(String(format: "%.2f", value)) \(unit)")
        #endif
      },
      getActiveTraces: {
        storage.getActiveTraces()
      },
      getRecentMetrics: { count in
        storage.getRecentMetrics(count)
      }
    )
  }()

  static let testValue = PerformanceClient()
}

extension DependencyValues {
  var performance: PerformanceClient {
    get { self[PerformanceClient.self] }
    set { self[PerformanceClient.self] = newValue }
  }
}

// MARK: - Storage

private final class PerformanceStorage: @unchecked Sendable {
  private let lock = NSLock()
  private var activeTraces: [UUID: PerformanceTrace] = [:]
  private var completedTraces: [PerformanceTrace] = []
  private var metrics: [PerformanceMetric] = []
  private let maxEntries = 500

  func startTrace(_ trace: PerformanceTrace) {
    lock.lock()
    defer { lock.unlock() }
    activeTraces[trace.id] = trace
  }

  func endTrace(_ id: UUID, metadata: [String: String]?) -> PerformanceTrace? {
    lock.lock()
    defer { lock.unlock() }

    guard var trace = activeTraces.removeValue(forKey: id) else { return nil }
    trace.endTime = Date()
    if let metadata {
      trace.metadata.merge(metadata) { _, new in new }
    }

    completedTraces.append(trace)
    if completedTraces.count > maxEntries {
      completedTraces.removeFirst(completedTraces.count - maxEntries)
    }

    return trace
  }

  func recordMetric(_ metric: PerformanceMetric) {
    lock.lock()
    defer { lock.unlock() }

    metrics.append(metric)
    if metrics.count > maxEntries {
      metrics.removeFirst(metrics.count - maxEntries)
    }
  }

  func getActiveTraces() -> [PerformanceTrace] {
    lock.lock()
    defer { lock.unlock() }
    return Array(activeTraces.values)
  }

  func getRecentMetrics(_ count: Int) -> [PerformanceMetric] {
    lock.lock()
    defer { lock.unlock() }
    return Array(metrics.suffix(count))
  }
}
