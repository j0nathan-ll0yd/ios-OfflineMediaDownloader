import Dependencies
import DependenciesMacros
import Foundation
import os.log
import Synchronization

// MARK: - Performance Types

public struct PerformanceTrace: Sendable {
  public let id: UUID
  public let name: String
  public let startTime: Date
  public var endTime: Date?
  public var metadata: [String: String]

  public var duration: TimeInterval? {
    guard let endTime else { return nil }
    return endTime.timeIntervalSince(startTime)
  }

  public init(id: UUID, name: String, startTime: Date, endTime: Date? = nil, metadata: [String: String] = [:]) {
    self.id = id
    self.name = name
    self.startTime = startTime
    self.endTime = endTime
    self.metadata = metadata
  }
}

public struct PerformanceMetric: Sendable {
  public let name: String
  public let value: Double
  public let unit: String
  public let timestamp: Date
  public let metadata: [String: String]?

  public init(name: String, value: Double, unit: String, timestamp: Date, metadata: [String: String]?) {
    self.name = name
    self.value = value
    self.unit = unit
    self.timestamp = timestamp
    self.metadata = metadata
  }
}

// MARK: - Performance Client

@DependencyClient
public struct PerformanceClient: Sendable {
  public var startTrace: @Sendable (String) -> UUID = { _ in UUID() }
  public var endTrace: @Sendable (UUID, [String: String]?) -> Void = { _, _ in }
  public var recordMetric: @Sendable (String, Double, String, [String: String]?) -> Void = { _, _, _, _ in }
  public var getActiveTraces: @Sendable () -> [PerformanceTrace] = { [] }
  public var getRecentMetrics: @Sendable (Int) -> [PerformanceMetric] = { _ in [] }
}

// MARK: - Convenience Methods

public extension PerformanceClient {
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

// MARK: - Debug Console Logger

/// os.log-based performance logging for DEBUG builds (avoids print() to comply with S47)
private let perfLog = OSLog(subsystem: "OfflineMediaDownloader", category: "Performance")

// MARK: - Live Implementation

extension PerformanceClient: DependencyKey {
  public static let liveValue: PerformanceClient = {
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
              // SANCTIONED-SINK: PerformanceClient's DEBUG live sink (trace duration)
              os_log("[Perf] [%{public}@] %.2fms", log: perfLog, type: .debug, trace.name, ms)
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
          // SANCTIONED-SINK: PerformanceClient's DEBUG live sink (metric value)
          os_log("[Perf] [%{public}@] %.2f %{public}@", log: perfLog, type: .debug, name, value, unit)
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

  public static let testValue = PerformanceClient()
}

public extension DependencyValues {
  var performance: PerformanceClient {
    get { self[PerformanceClient.self] }
    set { self[PerformanceClient.self] = newValue }
  }
}

// MARK: - Storage

private final class PerformanceStorage: Sendable {
  private struct State {
    var activeTraces: [UUID: PerformanceTrace] = [:]
    var completedTraces: [PerformanceTrace] = []
    var metrics: [PerformanceMetric] = []
  }

  private let storage = Mutex(State())
  private let maxEntries = 500

  func startTrace(_ trace: PerformanceTrace) {
    storage.withLock { $0.activeTraces[trace.id] = trace }
  }

  func endTrace(_ id: UUID, metadata: [String: String]?) -> PerformanceTrace? {
    storage.withLock { state in
      guard var trace = state.activeTraces.removeValue(forKey: id) else { return nil }
      trace.endTime = Date()
      if let metadata {
        trace.metadata.merge(metadata) { _, new in new }
      }
      state.completedTraces.append(trace)
      if state.completedTraces.count > maxEntries {
        state.completedTraces.removeFirst(state.completedTraces.count - maxEntries)
      }
      // S100: PerformanceTrace is a Sendable value type — safe to return from withLock.
      return trace
    }
  }

  func recordMetric(_ metric: PerformanceMetric) {
    storage.withLock { state in
      state.metrics.append(metric)
      if state.metrics.count > maxEntries {
        state.metrics.removeFirst(state.metrics.count - maxEntries)
      }
    }
  }

  func getActiveTraces() -> [PerformanceTrace] {
    // S100: return a Sendable value-type copy, never the protected State itself.
    storage.withLock { Array($0.activeTraces.values) }
  }

  func getRecentMetrics(_ count: Int) -> [PerformanceMetric] {
    // S100: return a Sendable value-type copy, never the protected State itself.
    storage.withLock { Array($0.metrics.suffix(count)) }
  }
}
