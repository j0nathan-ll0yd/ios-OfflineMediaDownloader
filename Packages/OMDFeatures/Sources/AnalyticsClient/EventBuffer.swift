import Foundation

/// The server rejected a `/device/event` batch with HTTP 400 (contract validation failed).
///
/// Resending the same batch cannot succeed, so `EventBuffer` drops it rather than
/// retrying or re-enqueuing it. The server also returns 400 for a missing or empty
/// `x-device-uuid` header, which is not a property of the batch, so the flush handler
/// never sends without a device ID: it throws `EventFlushError.deviceIdUnavailable`
/// instead, which `EventBuffer` retries and re-enqueues.
public struct EventBatchRejectedError: Error, Equatable {
  public let statusCode: Int

  public init(statusCode: Int) {
    self.statusCode = statusCode
  }
}

/// A flush that could not send yet. `EventBuffer` retries and re-enqueues the batch.
public enum EventFlushError: Error, Equatable {
  /// `identifierForVendor` was unavailable, for example before first unlock after a reboot.
  case deviceIdUnavailable
}

public actor EventBuffer {
  private var events: [ClientEvent] = []
  private var flushTask: Task<Void, Never>?
  private let flushHandler: @Sendable (Data) async throws -> Void
  private let logHandler: @Sendable (String) -> Void
  private let maxBatchSize: Int

  private static let defaultMaxBatchSize = 50
  private static let flushInterval: TimeInterval = 60
  /// Internal so tests can use it when building controlled failure sequences.
  static let maxRetries = 3
  // EB-1: cap on re-enqueued events after terminal send failure. If re-enqueuing the failed
  // batch would push the buffer beyond this limit, the oldest overflow events are dropped and
  // logged — never silently truncated.
  static let maxReenqueueCap = 200
  /// The contract's `maxItems` for `ClientEventBatchRequest.events`. The server rejects larger batches.
  static let maxEventsPerRequest = 100

  public init(
    flushHandler: @escaping @Sendable (Data) async throws -> Void,
    logHandler: @escaping @Sendable (String) -> Void = { _ in }
  ) {
    self.init(
      flushHandler: flushHandler,
      logHandler: logHandler,
      maxBatchSize: Self.defaultMaxBatchSize
    )
  }

  /// Internal seam for deterministic tests of buffering behavior that would
  /// otherwise trigger automatic background flushes at the production limit.
  init(
    flushHandler: @escaping @Sendable (Data) async throws -> Void,
    logHandler: @escaping @Sendable (String) -> Void,
    maxBatchSize: Int
  ) {
    self.flushHandler = flushHandler
    self.logHandler = logHandler
    self.maxBatchSize = maxBatchSize
  }

  public func start() {
    guard flushTask == nil else { return }
    flushTask = Task {
      while !Task.isCancelled {
        try? await Task.sleep(for: .seconds(Self.flushInterval))
        await flush()
      }
    }
  }

  public func append(_ event: ClientEvent) {
    events.append(event)
    if events.count >= maxBatchSize {
      Task { await flush() }
    }
  }

  public func flush() async {
    while !events.isEmpty {
      guard await sendNextBatch() else { return }
    }
  }

  /// Sends up to `maxEventsPerRequest` of the oldest events. Returns `false` when the
  /// send failed terminally and the batch was re-enqueued, which ends the flush.
  private func sendNextBatch() async -> Bool {
    // Snapshot and remove before the await so events appended during the send
    // form the next disjoint batch and are never double-sent (reentrancy-safe property).
    let batch = ClientEventBatch(events: Array(events.prefix(Self.maxEventsPerRequest)))
    events.removeFirst(batch.events.count)

    do {
      let data = try batch.jsonData()
      try await sendWithRetry(data)
      return true
    } catch let error as EventBatchRejectedError {
      logHandler("EventBuffer batch rejected (HTTP \(error.statusCode)): dropped \(batch.events.count) event(s)")
      return true
    } catch let error as EncodingError {
      // A batch that cannot encode never will, so re-enqueuing it would block every later flush.
      logHandler("EventBuffer batch could not encode: dropped \(batch.events.count) event(s). Error: \(error.localizedDescription)")
      return true
    } catch {
      // EB-1: all retries exhausted — re-enqueue the failed batch at the FRONT of events
      // so chronological order is preserved (failed events come before any events appended
      // during the await). Bounded by maxReenqueueCap: if the combined count exceeds the
      // cap, the oldest overflow events are dropped and logged rather than silently lost.
      // Note on ordering under concurrent terminal failures: if two flushes fail concurrently
      // and both re-enqueue, their batches can interleave across each other (each batch stays
      // internally ordered, but relative order across batches is not guaranteed). This is
      // acceptable for best-effort analytics — the server orders events by event timestamp.
      let combined = batch.events + events
      if combined.count > Self.maxReenqueueCap {
        let dropCount = combined.count - Self.maxReenqueueCap
        events = Array(combined.dropFirst(dropCount))
        logHandler(
          "EventBuffer flush failed (terminal): dropped \(dropCount) oldest event(s) to stay within cap(\(Self.maxReenqueueCap)). Error: \(error.localizedDescription)"
        )
      } else {
        events = combined
        logHandler("EventBuffer flush failed (terminal): re-enqueued \(batch.events.count) event(s) for next flush. Error: \(error.localizedDescription)")
      }
      return false
    }
  }

  private func sendWithRetry(_ data: Data) async throws {
    var lastError: (any Error)?
    for attempt in 0 ..< Self.maxRetries {
      if attempt > 0 {
        try? await Task.sleep(for: .seconds(pow(2.0, Double(attempt))))
      }
      do {
        try await flushHandler(data)
        return
      } catch let error as EventBatchRejectedError {
        throw error
      } catch {
        lastError = error
        logHandler("EventBuffer attempt \(attempt + 1) failed: \(error.localizedDescription)")
      }
    }
    throw lastError ?? URLError(.unknown)
  }

  /// - Parameters:
  ///   - deviceId: resolved on every flush, so a device ID that becomes available
  ///     later (for example after first unlock) is used for the events buffered before it.
  ///   - session: the session to upload through. Live, this is `\.analyticsURLSession`,
  ///     which pins the API Gateway certificate chain.
  ///   - infoDictionary: the bundle values that hold the endpoint and API key.
  public static func makeFlushHandler(
    deviceId: @escaping @Sendable () async -> String?,
    session: URLSession,
    infoDictionary: @escaping @Sendable () -> [String: Any]? = { Bundle.main.infoDictionary }
  ) -> @Sendable (Data) async throws -> Void {
    { data in
      guard let deviceId = await deviceId(), !deviceId.isEmpty else {
        throw EventFlushError.deviceIdUnavailable
      }

      let info = infoDictionary()
      guard let basePath = info?["MEDIA_DOWNLOADER_BASE_PATH"] as? String,
            let apiKey = info?["MEDIA_DOWNLOADER_API_KEY"] as? String,
            var urlComponents = URLComponents(string: basePath.hasSuffix("/") ? basePath + "device/event" : basePath + "/device/event")
      else {
        return
      }

      urlComponents.queryItems = (urlComponents.queryItems ?? []) + [
        URLQueryItem(name: "ApiKey", value: apiKey),
      ]

      guard let url = urlComponents.url else { return }

      var request = URLRequest(url: url)
      request.httpMethod = "POST"
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
      request.setValue(deviceId, forHTTPHeaderField: "x-device-uuid")
      request.httpBody = data
      request.timeoutInterval = 30

      let (_, response) = try await session.data(for: request)
      try classify(response)
    }
  }

  /// Maps a `/device/event` response to the flush outcome.
  ///
  /// - 2xx: sent.
  /// - 400: throws `EventBatchRejectedError`, which drops the batch.
  /// - Any other status, or a response that is not HTTP: throws `URLError(.badServerResponse)`,
  ///   which retries and then re-enqueues.
  static func classify(_ response: URLResponse) throws {
    guard let statusCode = (response as? HTTPURLResponse)?.statusCode else {
      throw URLError(.badServerResponse)
    }
    if statusCode == 400 {
      throw EventBatchRejectedError(statusCode: statusCode)
    }
    guard (200 ... 299).contains(statusCode) else {
      throw URLError(.badServerResponse)
    }
  }
}
