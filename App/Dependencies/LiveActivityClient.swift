import ComposableArchitecture

@DependencyClient
struct LiveActivityClient {
  var startActivityWithId: @Sendable (_ fileId: String) async -> Void
  var startActivity: @Sendable (_ file: File) async -> Void
  var updateProgress: @Sendable (_ fileId: String, _ percent: Int, _ status: DownloadActivityStatus) async -> Void
  var endActivity: @Sendable (_ fileId: String, _ status: DownloadActivityStatus, _ errorMessage: String?) async -> Void
}

extension DependencyValues {
  var liveActivityClient: LiveActivityClient {
    get { self[LiveActivityClient.self] }
    set { self[LiveActivityClient.self] = newValue }
  }
}

extension LiveActivityClient: DependencyKey {
  static let liveValue = Self(
    startActivityWithId: { fileId in
      await LiveActivityManager.shared.startActivityWithId(fileId: fileId)
    },
    startActivity: { file in
      await LiveActivityManager.shared.startActivity(for: file)
    },
    updateProgress: { fileId, percent, status in
      await LiveActivityManager.shared.updateProgress(fileId: fileId, percent: percent, status: status)
    },
    endActivity: { fileId, status, errorMessage in
      await LiveActivityManager.shared.endActivity(fileId: fileId, status: status, errorMessage: errorMessage)
    }
  )

  static let testValue = Self(
    startActivityWithId: { _ in },
    startActivity: { _ in },
    updateProgress: { _, _, _ in },
    endActivity: { _, _, _ in }
  )
}
