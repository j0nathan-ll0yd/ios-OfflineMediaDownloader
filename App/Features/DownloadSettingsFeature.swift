import ComposableArchitecture
import Foundation

@Reducer
struct DownloadSettingsFeature {
  @ObservableState
  struct State: Equatable {
    var downloadQuality: DownloadQuality = .auto
    var cellularDownloadsEnabled: Bool = false
  }

  enum Action {
    case onAppear
    case qualitySelected(DownloadQuality)
    case cellularToggled(Bool)
  }

  @Dependency(\.userDefaultsClient) var userDefaultsClient

  var body: some ReducerOf<Self> {
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
