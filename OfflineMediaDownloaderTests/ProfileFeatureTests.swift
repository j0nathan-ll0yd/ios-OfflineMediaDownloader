import ComposableArchitecture
import KeychainClient
import PersistenceClient
@testable import ProfileFeature
import SharedModels
import Testing

@MainActor
@Suite(.serialized)
struct ProfileFeatureTests {
  // MARK: - onAppear

  @Test("onAppear loads user identity and CoreData metrics")
  func onAppearLoadsUserAndMetrics() async {
    let metrics = FileMetrics(downloadCount: 7, totalStorageBytes: 3_000_000, playCount: 21)

    let store = TestStore(initialState: ProfileFeature.State()) {
      ProfileFeature()
    } withDependencies: {
      $0.keychainClient.getUserData = { TestData.sampleUser }
      $0.coreDataClient.getMetrics = { metrics }
      $0.logger = TestData.noopLogger
    }

    await store.send(.onAppear) {
      $0.isLoadingMetrics = true
    }
    await store.receive(\.userLoaded) {
      $0.user = TestData.sampleUser
    }
    await store.receive(\.metricsResponse) {
      $0.isLoadingMetrics = false
      $0.metrics = metrics
    }
  }

  // MARK: - Delegate routing

  @Test("signOutTapped emits signOut delegate")
  func signOutTappedEmitsDelegate() async {
    let store = TestStore(initialState: ProfileFeature.State()) {
      ProfileFeature()
    }

    await store.send(.signOutTapped)
    await store.receive(\.delegate.signOut)
  }

  @Test("downloadSettingsTapped emits openDownloadSettings delegate")
  func downloadSettingsTappedEmitsDelegate() async {
    let store = TestStore(initialState: ProfileFeature.State()) {
      ProfileFeature()
    }

    await store.send(.downloadSettingsTapped)
    await store.receive(\.delegate.openDownloadSettings)
  }

  #if DEBUG
    @Test("diagnosticsTapped emits openDiagnostics delegate")
    func diagnosticsTappedEmitsDelegate() async {
      let store = TestStore(initialState: ProfileFeature.State()) {
        ProfileFeature()
      }

      await store.send(.diagnosticsTapped)
      await store.receive(\.delegate.openDiagnostics)
    }
  #endif
}
