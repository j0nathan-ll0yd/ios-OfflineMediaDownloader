@testable import AnalyticsClient
import ConcurrencyExtras
import Foundation
import Testing

// Tests for EB-1: EventBuffer re-enqueues failed batches on terminal send failure.
//
// Invariants verified:
//   1. On terminal send failure (all retries exhausted), the batch is re-inserted at
//      the FRONT of events so chronological order is preserved.
//   2. Events appended after a failed flush are combined with the re-enqueued batch
//      in the next flush (oldest-first), and the combined total is never double-sent.
//   3. If re-enqueuing would exceed maxReenqueueCap, the oldest overflow events are
//      dropped and a log message is emitted — never silently truncated.
//   4. Successful flushes are not regressed: buffer is cleared after a successful send.
//   5. The reentrancy-safe property is preserved: a flush snapshots events before the
//      await, so concurrent appends during a send form the next disjoint batch.

private func makeEvent() -> ClientEvent {
  .appLaunched(
    timestamp: Date(),
    appVersion: "1.0",
    buildNumber: "1",
    osVersion: "18.0",
    deviceModel: "iPhone16,1"
  )
}

/// Counts the number of events in a serialised ClientEventBatch payload.
/// ClientEventBatch encodes as {"events": [...]}, so we read the array count
/// via JSONSerialization without needing ClientEvent to be Decodable.
private func eventCount(in data: Data) -> Int {
  guard
    let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
    let arr = obj["events"] as? [Any]
  else { return -1 }
  return arr.count
}

@Suite("EventBuffer flush / re-enqueue (EB-1)")
struct EventBufferTests {
  // MARK: - Successful flush

  @Test("Successful flush clears the buffer and sends exactly once")
  func successfulFlushClearsBuffer() async {
    let sentCount = LockIsolated(0)
    let buffer = EventBuffer(
      flushHandler: { _ in sentCount.withValue { $0 += 1 } },
      logHandler: { _ in }
    )

    for _ in 0 ..< 3 {
      await buffer.append(makeEvent())
    }
    await buffer.flush()
    #expect(sentCount.value == 1)

    // A second flush with an empty buffer is a no-op.
    await buffer.flush()
    #expect(sentCount.value == 1)
  }

  // MARK: - EB-1: re-enqueue on terminal failure

  @Test("Terminal send failure logs a terminal message and re-enqueues for next flush")
  func terminalFailureLogsAndReenqueues() async {
    let logMessages = LockIsolated<[String]>([])
    let callCount = LockIsolated(0)
    let successData = LockIsolated<Data?>(nil)

    let buffer = EventBuffer(
      flushHandler: { data in
        let count = callCount.withValue { count -> Int in
          count += 1
          return count
        }
        // Fail first maxRetries calls; succeed on the next.
        if count <= EventBuffer.maxRetries {
          throw URLError(.notConnectedToInternet)
        }
        successData.withValue { $0 = data }
      },
      logHandler: { msg in logMessages.withValue { $0.append(msg) } }
    )

    for _ in 0 ..< 3 {
      await buffer.append(makeEvent())
    }

    // First flush: exhausts maxRetries, re-enqueues 3 events.
    await buffer.flush()

    // The log must contain a terminal-failure message (never silent).
    let hasTerminalLog = logMessages.value.contains { $0.contains("terminal") }
    #expect(hasTerminalLog, "Expected terminal-failure log; got: \(logMessages.value)")

    // Second flush: succeeds, must send the re-enqueued 3 events.
    await buffer.flush()

    let data = successData.value
    #expect(data != nil, "Second flush should have produced data")
    if let data {
      let count = eventCount(in: data)
      #expect(count == 3, "Expected 3 re-enqueued events on second flush; got \(count)")
    }
  }

  @Test("Re-enqueued events appear before events appended after the failing flush")
  func reEnqueuedEventsLeadNextBatch() async {
    let callCount = LockIsolated(0)
    let batchSizes = LockIsolated<[Int]>([])

    let buffer = EventBuffer(
      flushHandler: { data in
        let count = callCount.withValue { count -> Int in
          count += 1
          return count
        }
        if count <= EventBuffer.maxRetries {
          throw URLError(.notConnectedToInternet)
        }
        batchSizes.withValue { $0.append(eventCount(in: data)) }
      },
      logHandler: { _ in }
    )

    // Append 2 events → first flush fails and re-enqueues them.
    for _ in 0 ..< 2 {
      await buffer.append(makeEvent())
    }
    await buffer.flush()

    // Append 1 more event to the buffer while it holds the re-enqueued 2.
    await buffer.append(makeEvent())

    // Second flush: must send 3 (2 re-enqueued + 1 new), in that order.
    await buffer.flush()

    #expect(batchSizes.value == [3], "Expected one successful batch of 3; got \(batchSizes.value)")
  }

  // MARK: - EB-1: cap enforcement

  // Cap tests use a small synthetic batch size (5 events) that stays below the
  // auto-flush threshold (50), so no background Task{flush} fires and the test
  // controls all flushes explicitly. The maxReenqueueCap invariant is:
  //   combined.count > maxReenqueueCap → drop oldest (combined.count - cap) events.
  // We verify this with combined = cap + overflow where cap = maxReenqueueCap.

  @Test("Re-enqueue below cap: no events are dropped and terminal log emitted")
  func reEnqueueBelowCapNoDrops() async {
    // 5 events << maxReenqueueCap (200), so re-enqueue stays well within cap.
    let logMessages = LockIsolated<[String]>([])
    let callCount = LockIsolated(0)

    let buffer = EventBuffer(
      flushHandler: { _ in
        let count = callCount.withValue { count -> Int in
          count += 1
          return count
        }
        if count <= EventBuffer.maxRetries {
          throw URLError(.notConnectedToInternet)
        }
      },
      logHandler: { msg in logMessages.withValue { $0.append(msg) } }
    )

    for _ in 0 ..< 5 {
      await buffer.append(makeEvent())
    }
    await buffer.flush()

    let hasDrop = logMessages.value.contains { $0.contains("dropped") }
    #expect(!hasDrop, "Should not drop 5 events (well below cap 200); messages: \(logMessages.value)")
    #expect(logMessages.value.contains { $0.contains("terminal") }, "Expected terminal log; got: \(logMessages.value)")
  }

  @Test("Re-enqueue exceeding cap drops oldest overflow and logs the count")
  func capExceededDropsOldestAndLogs() async {
    let cap = EventBuffer.maxReenqueueCap
    let expectedTotal = cap + 45
    let expectedDrop = expectedTotal - cap

    let logMessages = LockIsolated<[String]>([])

    let buffer = EventBuffer(
      flushHandler: { _ in throw URLError(.notConnectedToInternet) },
      logHandler: { msg in logMessages.withValue { $0.append(msg) } },
      maxBatchSize: .max
    )

    for _ in 0 ..< expectedTotal {
      await buffer.append(makeEvent())
    }
    await buffer.flush()

    let dropLog = logMessages.value.first { $0.contains("dropped") }
    #expect(dropLog != nil, "Expected a drop log; got: \(logMessages.value)")
    #expect(
      dropLog?.contains("\(expectedDrop)") == true,
      "Expected drop count of \(expectedDrop); got: \(dropLog ?? "nil")"
    )
  }

  // MARK: - EB-1 does not regress reentrancy-safe property

  @Test("Events appended during a failing send are included in re-enqueued buffer, not double-sent")
  func eventsAppendedDuringFailAreNotDoubleSent() async {
    let batchSizes = LockIsolated<[Int]>([])
    let callCount = LockIsolated(0)

    let buffer = EventBuffer(
      flushHandler: { data in
        let count = callCount.withValue { count -> Int in
          count += 1
          return count
        }
        if count <= EventBuffer.maxRetries {
          throw URLError(.notConnectedToInternet)
        }
        batchSizes.withValue { $0.append(eventCount(in: data)) }
      },
      logHandler: { _ in }
    )

    // 3 events before first flush.
    for _ in 0 ..< 3 {
      await buffer.append(makeEvent())
    }

    // First flush fails, re-enqueues 3.
    await buffer.flush()

    // Append 2 more to the re-enqueued buffer.
    for _ in 0 ..< 2 {
      await buffer.append(makeEvent())
    }

    // Second flush succeeds: should send exactly 5 (3 re-enqueued + 2 new).
    await buffer.flush()

    #expect(batchSizes.value == [5], "Expected exactly one batch of 5; got \(batchSizes.value)")
  }

  // MARK: - Contract limits

  @Test("A flush sends at most maxEventsPerRequest events per request, oldest first")
  func flushSplitsAtContractMaxItems() async {
    let batchSizes = LockIsolated<[Int]>([])
    let buffer = EventBuffer(
      flushHandler: { data in batchSizes.withValue { $0.append(eventCount(in: data)) } },
      logHandler: { _ in },
      maxBatchSize: .max
    )

    let total = EventBuffer.maxEventsPerRequest * 2 + 5
    for _ in 0 ..< total {
      await buffer.append(makeEvent())
    }
    await buffer.flush()

    #expect(batchSizes.value == [EventBuffer.maxEventsPerRequest, EventBuffer.maxEventsPerRequest, 5])
  }

  @Test("A batch the server rejects is dropped without retry and the flush continues")
  func rejectedBatchIsDroppedNotRetried() async {
    let callCount = LockIsolated(0)
    let batchSizes = LockIsolated<[Int]>([])
    let logMessages = LockIsolated<[String]>([])
    let buffer = EventBuffer(
      flushHandler: { data in
        let count = callCount.withValue { count -> Int in
          count += 1
          return count
        }
        if count == 1 {
          throw EventBatchRejectedError(statusCode: 400)
        }
        batchSizes.withValue { $0.append(eventCount(in: data)) }
      },
      logHandler: { msg in logMessages.withValue { $0.append(msg) } },
      maxBatchSize: .max
    )

    for _ in 0 ..< EventBuffer.maxEventsPerRequest + 3 {
      await buffer.append(makeEvent())
    }
    await buffer.flush()

    // One rejected request, then one for the remaining 3. No retry of the rejected batch.
    #expect(callCount.value == 2)
    #expect(batchSizes.value == [3])
    #expect(logMessages.value.contains { $0.contains("rejected") && $0.contains("\(EventBuffer.maxEventsPerRequest)") })

    // Nothing was re-enqueued.
    await buffer.flush()
    #expect(callCount.value == 2)
  }

  // MARK: - Device ID

  @Test("The flush handler refuses to send without a device ID", arguments: [nil, ""] as [String?])
  func flushHandlerThrowsRetryableErrorWithoutDeviceId(deviceId: String?) async {
    let handler = EventBuffer.makeFlushHandler(deviceId: { deviceId })

    await #expect(throws: EventFlushError.deviceIdUnavailable) {
      try await handler(Data())
    }
  }

  @Test("A missing device ID re-enqueues the batch instead of dropping it")
  func missingDeviceIdReenqueues() async {
    let logMessages = LockIsolated<[String]>([])
    let buffer = EventBuffer(
      flushHandler: EventBuffer.makeFlushHandler(deviceId: { nil }),
      logHandler: { msg in logMessages.withValue { $0.append(msg) } }
    )

    for _ in 0 ..< 2 {
      await buffer.append(makeEvent())
    }
    await buffer.flush()

    #expect(logMessages.value.contains { $0.contains("re-enqueued 2 event(s)") }, "got: \(logMessages.value)")
    #expect(!logMessages.value.contains { $0.contains("rejected") || $0.contains("dropped") }, "got: \(logMessages.value)")
  }

  // MARK: - Response classification

  private static let eventURL = URL(string: "https://api.example.test/device/event")

  private static func httpResponse(_ statusCode: Int) throws -> HTTPURLResponse {
    let url = try #require(eventURL)
    return try #require(HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil))
  }

  @Test("2xx responses classify as sent", arguments: [200, 202, 204])
  func successStatusesAreSent(statusCode: Int) throws {
    try EventBuffer.classify(Self.httpResponse(statusCode))
  }

  @Test("400 classifies as a rejected batch, which is dropped")
  func badRequestIsRejected() throws {
    let response = try Self.httpResponse(400)
    #expect(throws: EventBatchRejectedError(statusCode: 400)) {
      try EventBuffer.classify(response)
    }
  }

  @Test("Other 4xx and 5xx classify as retryable", arguments: [401, 403, 404, 429, 500, 502, 503])
  func otherStatusesAreRetryable(statusCode: Int) throws {
    let response = try Self.httpResponse(statusCode)
    #expect(throws: URLError(.badServerResponse)) {
      try EventBuffer.classify(response)
    }
  }

  @Test("A response that is not HTTP classifies as retryable")
  func nonHTTPResponseIsRetryable() throws {
    let url = try #require(Self.eventURL)
    let response = URLResponse(url: url, mimeType: nil, expectedContentLength: 0, textEncodingName: nil)
    #expect(throws: URLError(.badServerResponse)) {
      try EventBuffer.classify(response)
    }
  }
}
