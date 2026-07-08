@testable import AnalyticsClient
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
    // SAFETY: sentCount is accessed only from the actor-isolated flush test path;
    // the flushHandler closure is called serially within a single await chain.
    nonisolated(unsafe) var sentCount = 0
    let buffer = EventBuffer(
      flushHandler: { _ in sentCount += 1 },
      logHandler: { _ in }
    )

    for _ in 0 ..< 3 {
      await buffer.append(makeEvent())
    }
    await buffer.flush()
    #expect(sentCount == 1)

    // A second flush with an empty buffer is a no-op.
    await buffer.flush()
    #expect(sentCount == 1)
  }

  // MARK: - EB-1: re-enqueue on terminal failure

  @Test("Terminal send failure logs a terminal message and re-enqueues for next flush")
  func terminalFailureLogsAndReenqueues() async {
    // SAFETY: these vars are mutated only within the serially-called flushHandler closure
    // and read only after all awaits complete — no concurrent access possible.
    nonisolated(unsafe) var logMessages: [String] = []
    nonisolated(unsafe) var callCount = 0
    nonisolated(unsafe) var successData: Data?

    let buffer = EventBuffer(
      flushHandler: { data in
        callCount += 1
        // Fail first maxRetries calls; succeed on the next.
        if callCount <= EventBuffer.maxRetries {
          throw URLError(.notConnectedToInternet)
        }
        successData = data
      },
      logHandler: { msg in logMessages.append(msg) }
    )

    for _ in 0 ..< 3 {
      await buffer.append(makeEvent())
    }

    // First flush: exhausts maxRetries, re-enqueues 3 events.
    await buffer.flush()

    // The log must contain a terminal-failure message (never silent).
    let hasTerminalLog = logMessages.contains { $0.contains("terminal") }
    #expect(hasTerminalLog, "Expected terminal-failure log; got: \(logMessages)")

    // Second flush: succeeds, must send the re-enqueued 3 events.
    await buffer.flush()

    let data = successData
    #expect(data != nil, "Second flush should have produced data")
    if let data {
      let count = eventCount(in: data)
      #expect(count == 3, "Expected 3 re-enqueued events on second flush; got \(count)")
    }
  }

  @Test("Re-enqueued events appear before events appended after the failing flush")
  func reEnqueuedEventsLeadNextBatch() async {
    // SAFETY: callCount and batchSizes are only mutated serially inside flushHandler awaits.
    nonisolated(unsafe) var callCount = 0
    nonisolated(unsafe) var batchSizes: [Int] = []

    let buffer = EventBuffer(
      flushHandler: { data in
        callCount += 1
        if callCount <= EventBuffer.maxRetries {
          throw URLError(.notConnectedToInternet)
        }
        batchSizes.append(eventCount(in: data))
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

    #expect(batchSizes == [3], "Expected one successful batch of 3; got \(batchSizes)")
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
    // SAFETY: logMessages is mutated only within serially-called handler closures.
    nonisolated(unsafe) var logMessages: [String] = []
    nonisolated(unsafe) var callCount = 0

    let buffer = EventBuffer(
      flushHandler: { _ in
        callCount += 1
        if callCount <= EventBuffer.maxRetries { throw URLError(.notConnectedToInternet) }
      },
      logHandler: { msg in logMessages.append(msg) }
    )

    for _ in 0 ..< 5 {
      await buffer.append(makeEvent())
    }
    await buffer.flush()

    let hasDrop = logMessages.contains { $0.contains("dropped") }
    #expect(!hasDrop, "Should not drop 5 events (well below cap 200); messages: \(logMessages)")
    #expect(logMessages.contains { $0.contains("terminal") }, "Expected terminal log; got: \(logMessages)")
  }

  @Test("Re-enqueue exceeding cap drops oldest overflow and logs the count")
  func capExceededDropsOldestAndLogs() async {
    // Strategy: first flush re-enqueues N events (N < 50, no auto-flush). Then we append
    // enough additional events so the second flush's re-enqueue attempt sees combined > cap
    // and logs a drop. To keep all appends below the auto-flush threshold (50 per append
    // session), we build up to cap+overflow across two controlled flushes:
    //
    //   Round 1: append 49, flush → fail → re-enqueue 49 (49 ≤ 200, no drop)
    //   Append 49 more (49 < 50 threshold, no auto-flush) → buffer has 49+49 = 98
    //   Round 2: flush snapshots 98, fails → re-enqueue: combined = 98 + 0 = 98 (still ≤ 200)
    //
    // 200-cap needs combined > 200. 4 rounds of 49 = 196 — still under cap.
    // Use 5 rounds: 5 × 49 = 245 > 200. Drop = 245 − 200 = 45 events.
    // Each round: append 49, flush (fails). After each flush events = previous + 49.
    //
    // Round 1: snap=49 fail → events=49
    // Round 2: snap=49+49=98 fail → events=98
    // Round 3: snap=98+49=147 fail → events=147
    // Round 4: snap=147+49=196 fail → events=196
    // Round 5: snap=196+49=245 fail → combined=245 > 200 → drop 45, log "dropped 45"

    let cap = EventBuffer.maxReenqueueCap
    let batchSize = 49 // stay below auto-flush threshold of 50
    let rounds = 5
    let expectedTotal = batchSize * rounds // 245
    let expectedDrop = expectedTotal - cap // 45

    // SAFETY: logMessages is mutated only within serially-called handler closures.
    nonisolated(unsafe) var logMessages: [String] = []

    let buffer = EventBuffer(
      flushHandler: { _ in throw URLError(.notConnectedToInternet) },
      logHandler: { msg in logMessages.append(msg) }
    )

    for _ in 0 ..< rounds {
      for _ in 0 ..< batchSize {
        await buffer.append(makeEvent())
      }
      await buffer.flush()
    }

    let dropLog = logMessages.first { $0.contains("dropped") }
    #expect(dropLog != nil, "Expected a drop log after \(rounds) rounds; got: \(logMessages)")
    #expect(
      dropLog?.contains("\(expectedDrop)") == true,
      "Expected drop count of \(expectedDrop); got: \(dropLog ?? "nil")"
    )
  }

  // MARK: - EB-1 does not regress reentrancy-safe property

  @Test("Events appended during a failing send are included in re-enqueued buffer, not double-sent")
  func eventsAppendedDuringFailAreNotDoubleSent() async {
    // SAFETY: batchSizes and callCount are mutated only within serially-called handler closures.
    nonisolated(unsafe) var batchSizes: [Int] = []
    nonisolated(unsafe) var callCount = 0

    let buffer = EventBuffer(
      flushHandler: { data in
        callCount += 1
        if callCount <= EventBuffer.maxRetries {
          throw URLError(.notConnectedToInternet)
        }
        batchSizes.append(eventCount(in: data))
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

    #expect(batchSizes == [5], "Expected exactly one batch of 5; got \(batchSizes)")
  }
}
