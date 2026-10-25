import Dependencies
import DependenciesMacros
import Foundation

/// Monotonic time for analytics durations.
///
/// `Date` differences jump when the user or the network changes the wall clock: a backward
/// change gives a negative duration and a forward change gives a wrong large one. `now()`
/// reads `ContinuousClock`, which never jumps and keeps counting while the device sleeps.
/// The value is the time since an arbitrary origin fixed at first use in this process, so
/// it is only meaningful as the difference of two readings.
@DependencyClient
public struct MonotonicClock: Sendable {
  public var now: @Sendable () -> Duration = { .zero }
}

public extension DependencyValues {
  var monotonicClock: MonotonicClock {
    get { self[MonotonicClock.self] }
    set { self[MonotonicClock.self] = newValue }
  }
}

extension MonotonicClock: DependencyKey {
  public static let liveValue: MonotonicClock = {
    let origin = ContinuousClock.now
    return MonotonicClock(now: { ContinuousClock.now - origin })
  }()
}

public extension Duration {
  /// Whole milliseconds, rounded down.
  var wholeMilliseconds: Int {
    Int((self / .milliseconds(1)).rounded(.down))
  }

  /// Seconds as a floating-point value.
  var seconds: Double {
    self / .seconds(1)
  }
}
