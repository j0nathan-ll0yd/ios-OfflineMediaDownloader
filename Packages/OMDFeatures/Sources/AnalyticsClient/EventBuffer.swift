import Foundation
import os.log

public actor EventBuffer {
  private var events: [ClientEvent] = []
  private var flushTask: Task<Void, Never>?
  private let flushHandler: @Sendable (Data) async throws -> Void

  private static let maxBatchSize = 50
  private static let flushInterval: TimeInterval = 60
  private static let maxRetries = 3
  private static let bufferLog = OSLog(subsystem: "OfflineMediaDownloader", category: "EventBuffer")

  public init(flushHandler: @escaping @Sendable (Data) async throws -> Void) {
    self.flushHandler = flushHandler
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
    let batch = ClientEventBatch(events: events)
    events.removeAll()

    do {
      let data = try JSONEncoder().encode(batch)
      try await sendWithRetry(data)
    } catch {
      os_log("EventBuffer flush failed: %{public}@", log: Self.bufferLog, type: .error, error.localizedDescription)
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
        os_log("EventBuffer attempt %d failed: %{public}@", log: Self.bufferLog, type: .error, attempt + 1, error.localizedDescription)
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
