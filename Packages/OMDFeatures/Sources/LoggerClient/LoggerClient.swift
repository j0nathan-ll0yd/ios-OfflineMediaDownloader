import Dependencies
import DependenciesMacros
import Foundation
import os.log
import Synchronization

// MARK: - Log Types

public enum LogLevel: Int, Sendable, Comparable {
  case debug = 0
  case info = 1
  case warning = 2
  case error = 3
  case critical = 4

  public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
    lhs.rawValue < rhs.rawValue
  }

  public var osLogType: OSLogType {
    switch self {
    case .debug: .debug
    case .info: .info
    case .warning: .default
    case .error: .error
    case .critical: .fault
    }
  }

  public var emoji: String {
    switch self {
    case .debug: "🔍"
    case .info: "ℹ️"
    case .warning: "⚠️"
    case .error: "❌"
    case .critical: "🔥"
    }
  }
}

public enum LogCategory: String, Sendable {
  case auth = "Auth"
  case network = "Network"
  case download = "Download"
  case storage = "Storage"
  case ui = "UI"
  case push = "Push"
  case performance = "Performance"
  case lifecycle = "Lifecycle"

  public var osLog: OSLog {
    OSLog(subsystem: Bundle.main.bundleIdentifier ?? "OfflineMediaDownloader", category: rawValue)
  }
}

public struct LogEntry: Equatable, Sendable, Identifiable {
  public let id: UUID
  public let timestamp: Date
  public let level: LogLevel
  public let category: LogCategory
  public let message: String
  public let metadata: [String: String]?
  public let file: String
  public let line: Int

  public init(
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
public struct LoggerClient: Sendable {
  public var log: @Sendable (LogLevel, LogCategory, String, [String: String]?, String, Int) -> Void
  public var getRecentLogs: @Sendable (Int) -> [LogEntry] = { _ in [] }
  public var clearLogs: @Sendable () -> Void = {}
  public var exportLogs: @Sendable () async throws -> Data = { Data() }
  public var setMinLevel: @Sendable (LogLevel) -> Void = { _ in }
}

// MARK: - Convenience Methods

public extension LoggerClient {
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

// MARK: - Debug Console Logger

/// os.log-based console logger for DEBUG builds (avoids print() to comply with S47)
private let debugConsoleLog = OSLog(subsystem: "OfflineMediaDownloader.Debug", category: "Console")

// MARK: - Live Implementation

extension LoggerClient: DependencyKey {
  public static let liveValue: LoggerClient = {
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
        // SANCTIONED-SINK: LoggerClient's own live os.log sink (primary system log output)
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

        // Also log via os_log in DEBUG for Xcode console visibility
        #if DEBUG
          let timestamp = ISO8601DateFormatter().string(from: entry.timestamp)
          let debugMsg = "\(level.emoji) [\(timestamp)] [\(category.rawValue)] \(message)"
          // SANCTIONED-SINK: LoggerClient's DEBUG Xcode console visibility sink
          os_log("%{public}@", log: debugConsoleLog, type: .debug, debugMsg)
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

  public static let testValue = LoggerClient()
}

public extension DependencyValues {
  var logger: LoggerClient {
    get { self[LoggerClient.self] }
    set { self[LoggerClient.self] = newValue }
  }
}

// MARK: - Storage

/// `minLevel` is folded into `State` so both the level-filter read (liveValue:165) and
/// the setMinLevel write (liveValue:203) are always covered by the same lock, closing
/// the latent data race present in the NSLock version (where minLevel was unguarded).
private final class LogStorage: Sendable {
  private struct State {
    var entries: [LogEntry] = []
    var minLevel: LogLevel = .debug
  }

  private let storage = Mutex(State())
  private let maxEntries = 1000

  var minLevel: LogLevel {
    get { storage.withLock { $0.minLevel } }
    set { storage.withLock { $0.minLevel = newValue } }
  }

  func append(_ entry: LogEntry) {
    storage.withLock { state in
      state.entries.append(entry)
      if state.entries.count > maxEntries {
        state.entries.removeFirst(state.entries.count - maxEntries)
      }
    }
  }

  func getRecent(_ count: Int) -> [LogEntry] {
    // S100: return a Sendable value-type copy, never the protected State itself.
    storage.withLock { Array($0.entries.suffix(count)) }
  }

  func clear() {
    storage.withLock { $0.entries.removeAll() }
  }

  func exportJSON() throws -> Data {
    // S100: extract a value-type copy before releasing the lock, then serialize outside.
    let entries = storage.withLock { Array($0.entries) }

    let exportable = entries.map { entry -> [String: Any] in
      var dict: [String: Any] = [
        "id": entry.id.uuidString,
        "timestamp": ISO8601DateFormatter().string(from: entry.timestamp),
        "level": entry.level.rawValue,
        "category": entry.category.rawValue,
        "message": entry.message,
        "file": entry.file,
        "line": entry.line,
      ]
      if let metadata = entry.metadata {
        dict["metadata"] = metadata
      }
      return dict
    }

    return try JSONSerialization.data(withJSONObject: exportable, options: [.prettyPrinted, .sortedKeys])
  }
}
