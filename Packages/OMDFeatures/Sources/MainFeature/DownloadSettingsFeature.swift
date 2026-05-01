import ComposableArchitecture
import Foundation

@Reducer
public struct DownloadSettingsFeature: Sendable {
  public init() {}

  @ObservableState
  public struct State: Equatable, Sendable {
    public var downloadQuality: DownloadQuality = .auto
    public var cellularDownloadsEnabled: Bool = false

    public init() {}
  }

  public enum Action: Sendable {
    case onAppear
    case qualitySelected(DownloadQuality)
    case cellularToggled(Bool)
  }

  @Dependency(\.userDefaultsClient) var userDefaultsClient

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .onAppear:
        state.downloadQuality = userDefaultsClient.getDownloadQuality()
        state.cellularDownloadsEnabled = userDefaultsClient.getCellularDownloadsEnabled()
        return .none

      case let .qualitySelected(quality):
        state.downloadQuality = quality
        return .run { [quality] _ in
          userDefaultsClient.setDownloadQuality(quality)
        }

      case let .cellularToggled(enabled):
        state.cellularDownloadsEnabled = enabled
        return .run { [enabled] _ in
          userDefaultsClient.setCellularDownloadsEnabled(enabled)
        }
      }
    }
  }
}
