import ComposableArchitecture
import Foundation
import SwiftUI

struct KeychainItem: Equatable, Identifiable, Sendable {
  var id: String { name }
  var name: String
  var displayValue: String
  var itemType: KeychainItemType

  enum KeychainItemType: Equatable, Sendable {
    case token
    case userData
    case deviceData
  }
}

@Reducer
struct DiagnosticFeature {
  @ObservableState
  struct State: Equatable {
    var keychainItems: [KeychainItem] = []
    var showDebugActions: Bool = false
    var isLoading: Bool = false
    @Presents var alert: AlertState<Action.Alert>?
    // Metrics
    var downloadCount: Int = 0
    var totalStorageBytes: Int64 = 0
    var playCount: Int = 0
  }

  enum Action {
    case onAppear
    case toggleDebugMode
    case keychainItemsLoaded([KeychainItem])
    case deleteKeychainItem(IndexSet)
    case keychainItemDeleted(KeychainItem.KeychainItemType)
    case truncateFilesButtonTapped
    case filesTruncated
    case showError(AppError)
    case alert(PresentationAction<Alert>)
    case delegate(Delegate)
    // Metrics
    case loadMetrics
    case metricsLoaded(FileMetrics)

    @CasePathable
    enum Alert: Equatable {
      case dismiss
    }

    @CasePathable
    enum Delegate: Equatable {
      case authenticationInvalidated
    }
  }

  @Dependency(\.keychainClient) var keychainClient
  @Dependency(\.coreDataClient) var coreDataClient

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .onAppear:
        state.isLoading = true
        return .merge(
          .run { send in
            var items: [KeychainItem] = []

            // Load JWT Token
            if let token = try await keychainClient.getJwtToken() {
              items.append(KeychainItem(
                name: "Token",
                displayValue: token,
                itemType: .token
              ))
            }

            // Load User Data
            if let userData = try? await keychainClient.getUserData() {
              items.append(KeychainItem(
                name: "UserData",
                displayValue: "\(userData.firstName) \(userData.lastName) (\(userData.email))",
                itemType: .userData
              ))
            }

            // Load Device Data
            if let deviceData = try await keychainClient.getDeviceData() {
              items.append(KeychainItem(
                name: "DeviceData",
                displayValue: deviceData.endpointArn,
                itemType: .deviceData
              ))
            }

            await send(.keychainItemsLoaded(items))
          },
          .send(.loadMetrics)
        )

      case let .keychainItemsLoaded(items):
        state.keychainItems = items
        state.isLoading = false
        return .none

      case .toggleDebugMode:
        state.showDebugActions.toggle()
        return .none

      case let .deleteKeychainItem(indexSet):
        guard let index = indexSet.first else { return .none }
        let item = state.keychainItems[index]
        state.keychainItems.remove(atOffsets: indexSet)

        return .run { send in
          do {
            switch item.itemType {
            case .token:
              try await keychainClient.deleteJwtToken()
            case .userData:
              try await keychainClient.deleteUserData()
            case .deviceData:
              try await keychainClient.deleteDeviceData()
            }
            await send(.keychainItemDeleted(item.itemType))
          } catch {
            await send(.showError(.keychainError(operation: "delete \(item.name)")))
          }
        }

      case let .keychainItemDeleted(itemType):
        // Deleting token or user data invalidates authentication
        if itemType == .token || itemType == .userData {
          return .send(.delegate(.authenticationInvalidated))
        }
        return .none

      case .truncateFilesButtonTapped:
        return .run { send in
          do {
            try await coreDataClient.truncateFiles()
            try await coreDataClient.resetMetrics()
            await send(.filesTruncated)
          } catch {
            await send(.showError(.storageError(operation: "truncate files")))
          }
        }

      case .filesTruncated:
        // Reload metrics after truncate
        return .send(.loadMetrics)

      case let .showError(appError):
        state.alert = AlertState {
          TextState(appError.title)
        } actions: {
          ButtonState(role: .cancel, action: .dismiss) {
            TextState("OK")
          }
        } message: {
          TextState(appError.message)
        }
        return .none

      case .alert:
        return .none

      case .delegate:
        return .none

      case .loadMetrics:
        return .run { send in
          do {
            let metrics = try await coreDataClient.getMetrics()
            await send(.metricsLoaded(metrics))
          } catch {
            print("📊 Failed to load metrics: \(error)")
          }
        }

      case let .metricsLoaded(metrics):
        state.downloadCount = metrics.downloadCount
        state.totalStorageBytes = metrics.totalStorageBytes
        state.playCount = metrics.playCount
        return .none
      }
    }
    .ifLet(\.$alert, action: \.alert)
  }
}
