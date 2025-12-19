import Dependencies
import DependenciesMacros
import Foundation
import os.log

// MARK: - Log Types

enum LogLevel: Int, Sendable, Comparable {
  case debug = 0
  case info = 1
  case warning = 2
  case error = 3
  case critical = 4

  static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
    lhs.rawValue < rhs.rawValue
  }

  var osLogType: OSLogType {
    switch self {
    case .debug: return .debug
    case .info: return .info
    case .warning: return .default
    case .error: return .error
    case .critical: return .fault
    }
  }

  var emoji: String {
    switch self {
    case .debug: return "🔍"
    case .info: return "ℹ️"
    case .warning: return "⚠️"
    case .error: return "❌"
    case .critical: return "🔥"
    }
  }
}

enum LogCategory: String, Sendable {
  case auth = "Auth"
  case network = "Network"
  case download = "Download"
  case storage = "Storage"
  case ui = "UI"
  case push = "Push"
  case performance = "Performance"
  case lifecycle = "Lifecycle"

  var osLog: OSLog {
    OSLog(subsystem: Bundle.main.bundleIdentifier ?? "OfflineMediaDownloader", category: rawValue)
  }
}

struct LogEntry: Equatable, Sendable, Identifiable {
  let id: UUID
  let timestamp: Date
  let level: LogLevel
  let category: LogCategory
  let message: String
  let metadata: [String: String]?
  let file: String
  let line: Int

  init(
    id: UUID = UUID(),
    timestamp: Date = Date(),
    level: LogLevel,
    category: LogCategory,
    message: String,
    metadata: [String: String]? = nil,
    file: String,
    line: Int
  ) {
    self.id = id
    self.timestamp = timestamp
    self.level = level
    self.category = category
    self.message = message
    self.metadata = metadata
    self.file = file
    self.line = line
  }
}

// MARK: - Logger Client

@DependencyClient
struct LoggerClient: Sendable {
  var log: @Sendable (LogLevel, LogCategory, String, [String: String]?, String, Int) -> Void
  var getRecentLogs: @Sendable (Int) -> [LogEntry] = { _ in [] }
  var clearLogs: @Sendable () -> Void = {}
  var exportLogs: @Sendable () async throws -> Data = { Data() }
  var setMinLevel: @Sendable (LogLevel) -> Void = { _ in }
}

// MARK: - Convenience Methods

extension LoggerClient {
  func debug(
    _ category: LogCategory,
    _ message: String,
    metadata: [String: String]? = nil,
    file: String = #file,
    line: Int = #line
  ) {
    log(.debug, category, message, metadata, file, line)
  }

  func info(
    _ category: LogCategory,
    _ message: String,
    metadata: [String: String]? = nil,
    file: String = #file,
    line: Int = #line
  ) {
    log(.info, category, message, metadata, file, line)
  }

  func warning(
    _ category: LogCategory,
    _ message: String,
    metadata: [String: String]? = nil,
    file: String = #file,
    line: Int = #line
  ) {
    log(.warning, category, message, metadata, file, line)
  }

  func error(
    _ category: LogCategory,
    _ message: String,
    metadata: [String: String]? = nil,
    file: String = #file,
    line: Int = #line
  ) {
    log(.error, category, message, metadata, file, line)
  }

  func critical(
    _ category: LogCategory,
    _ message: String,
    metadata: [String: String]? = nil,
    file: String = #file,
    line: Int = #line
  ) {
    log(.critical, category, message, metadata, file, line)
  }
}

// MARK: - Live Implementation

extension LoggerClient: DependencyKey {
  static let liveValue: LoggerClient = {
    let storage = LogStorage()

    return LoggerClient(
      log: { level, category, message, metadata, file, line in
        // Skip if below minimum level
        guard level >= storage.minLevel else { return }

        // Log to os.log for system integration
        let metadataString = metadata.map { dict in
          dict.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
        } ?? ""

        let fullMessage = metadataString.isEmpty ? message : "\(message) [\(metadataString)]"
        os_log("%{public}@", log: category.osLog, type: level.osLogType, fullMessage)

        // Store in memory for debugging
        let entry = LogEntry(
          level: level,
          category: category,
          message: message,
          metadata: metadata,
          file: (file as NSString).lastPathComponent,
          line: line
        )
        storage.append(entry)

        // Also print in DEBUG for Xcode console visibility
        #if DEBUG
        let timestamp = ISO8601DateFormatter().string(from: entry.timestamp)
        print("\(level.emoji) [\(timestamp)] [\(category.rawValue)] \(message)")
        #endif
      },
      getRecentLogs: { count in
        storage.getRecent(count)
      },
      clearLogs: {
        storage.clear()
      },
      exportLogs: {
        try storage.exportJSON()
      },
      setMinLevel: { level in
        storage.minLevel = level
      }
    )
  }()

  static let testValue = LoggerClient()
}

extension DependencyValues {
  var logger: LoggerClient {
    get { self[LoggerClient.self] }
    set { self[LoggerClient.self] = newValue }
  }
}

// MARK: - Storage

private final class LogStorage: @unchecked Sendable {
  private let lock = NSLock()
  private var entries: [LogEntry] = []
  private let maxEntries = 1000

  var minLevel: LogLevel = .debug

  func append(_ entry: LogEntry) {
    lock.lock()
    defer { lock.unlock() }

    entries.append(entry)
    if entries.count > maxEntries {
      entries.removeFirst(entries.count - maxEntries)
    }
  }

  func getRecent(_ count: Int) -> [LogEntry] {
    lock.lock()
    defer { lock.unlock() }

    return Array(entries.suffix(count))
  }

  func clear() {
    lock.lock()
    defer { lock.unlock() }
    entries.removeAll()
  }

  func exportJSON() throws -> Data {
    lock.lock()
    defer { lock.unlock() }

    let exportable = entries.map { entry -> [String: Any] in
      var dict: [String: Any] = [
        "id": entry.id.uuidString,
        "timestamp": ISO8601DateFormatter().string(from: entry.timestamp),
        "level": entry.level.rawValue,
        "category": entry.category.rawValue,
        "message": entry.message,
        "file": entry.file,
        "line": entry.line
      ]
      if let metadata = entry.metadata {
        dict["metadata"] = metadata
      }
      return dict
    }

    return try JSONSerialization.data(withJSONObject: exportable, options: [.prettyPrinted, .sortedKeys])
  }
}
