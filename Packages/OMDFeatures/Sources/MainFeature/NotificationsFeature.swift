import ComposableArchitecture
import Foundation

/// Notification preferences. Toggles persist to `UserDefaults` via `@Shared`
/// app storage so the choices survive launches; push registration reads these
/// flags when deciding which alerts to deliver.
@Reducer
public struct NotificationsFeature: Sendable {
  public init() {}

  @ObservableState
  public struct State: Equatable {
    @Shared(.appStorage("notifications.downloadComplete")) public var downloadComplete = true
    @Shared(.appStorage("notifications.newContent")) public var newContent = true
    @Shared(.appStorage("notifications.productUpdates")) public var productUpdates = false

    public init() {}
  }

  public enum Action: Sendable {
    case downloadCompleteToggled(Bool)
    case newContentToggled(Bool)
    case productUpdatesToggled(Bool)
  }

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case let .downloadCompleteToggled(value):
        state.$downloadComplete.withLock { $0 = value }
        return .none

      case let .newContentToggled(value):
        state.$newContent.withLock { $0 = value }
        return .none

      case let .productUpdatesToggled(value):
        state.$productUpdates.withLock { $0 = value }
        return .none
      }
    }
  }
}
