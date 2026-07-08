import Foundation

public actor EventBuffer {
  private var events: [ClientEvent] = []
  private var flushTask: Task<Void, Never>?
  private let flushHandler: @Sendable (Data) async throws -> Void
  private let logHandler: @Sendable (String) -> Void

  private static let maxBatchSize = 50
  private static let flushInterval: TimeInterval = 60
  /// Internal so tests can use it when building controlled failure sequences.
  static let maxRetries = 3
  // EB-1: cap on re-enqueued events after terminal send failure. If re-enqueuing the failed
  // batch would push the buffer beyond this limit, the oldest overflow events are dropped and
  // logged — never silently truncated.
  static let maxReenqueueCap = 200

  public init(
    flushHandler: @escaping @Sendable (Data) async throws -> Void,
    logHandler: @escaping @Sendable (String) -> Void = { _ in }
  ) {
    self.flushHandler = flushHandler
    self.logHandler = logHandler
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
    if events.count >= Self.maxBatchSize {
      Task { await flush() }
    }
  }

  public func flush() async {
    guard !events.isEmpty else { return }
    // Snapshot and clear before the await so events appended during the send
    // form the next disjoint batch and are never double-sent (reentrancy-safe property).
    let batch = ClientEventBatch(events: events)
    events.removeAll()

    do {
      let data = try JSONEncoder().encode(batch)
      try await sendWithRetry(data)
    } catch {
      // EB-1: all retries exhausted — re-enqueue the failed batch at the FRONT of events
      // so chronological order is preserved (failed events come before any events appended
      // during the await). Bounded by maxReenqueueCap: if the combined count exceeds the
      // cap, the oldest overflow events are dropped and logged rather than silently lost.
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
      } catch {
        lastError = error
        logHandler("EventBuffer attempt \(attempt + 1) failed: \(error.localizedDescription)")
      }
    }
    throw lastError ?? URLError(.unknown)
  }

  public static func makeFlushHandler(deviceId: String) -> @Sendable (Data) async throws -> Void {
    { data in
      guard let basePath = Bundle.main.infoDictionary?["MEDIA_DOWNLOADER_BASE_PATH"] as? String,
            let apiKey = Bundle.main.infoDictionary?["MEDIA_DOWNLOADER_API_KEY"] as? String,
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

      let (_, response) = try await URLSession.shared.data(for: request)
      guard let httpResponse = response as? HTTPURLResponse,
            (200 ... 299).contains(httpResponse.statusCode)
      else {
        throw URLError(.badServerResponse)
      }
    }
  }
}
