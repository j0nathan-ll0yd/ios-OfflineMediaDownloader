import ComposableArchitecture
import Foundation
import SwiftUI
import SharedModels
import KeychainClient
import PersistenceClient
import ServerClient
import LoggerClient
import APIClient

public struct KeychainItem: Equatable, Identifiable, Sendable {
  public var id: String { name }
  public var name: String
  public var displayValue: String
  public var itemType: KeychainItemType

  public enum KeychainItemType: Equatable, Sendable {
    case token
    case userData
    case deviceData
  }

  public init(name: String, displayValue: String, itemType: KeychainItemType) {
    self.name = name
    self.displayValue = displayValue
    self.itemType = itemType
  }
}

@Reducer
public struct DiagnosticFeature: Sendable {
  public init() {}

  @ObservableState
  public struct State: Equatable {
    public var keychainItems: [KeychainItem] = []
    public var showDebugActions: Bool = false
    public var isLoading: Bool = false
    @Presents public var alert: AlertState<Action.Alert>?
    public var downloadCount: Int = 0
    public var totalStorageBytes: Int64 = 0
    public var playCount: Int = 0
    public var tokenExpiresAt: Date?

    public init() {}
  }

  public enum Action {
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
    case loadMetrics
    case metricsLoaded(FileMetrics)
    case tokenExpirationLoaded(Date?)
    case deleteTokenExpiration
    case setTokenExpiringSoon
    case tokenExpirationUpdated
    case signOutButtonTapped
    case signOutCompleted

    @CasePathable
    public enum Alert: Equatable {
      case dismiss
    }

    @CasePathable
    public enum Delegate: Equatable {
      case authenticationInvalidated
      case signedOut
    }
  }

  @Dependency(\.keychainClient) var keychainClient
  @Dependency(\.coreDataClient) var coreDataClient
  @Dependency(\.serverClient) var serverClient
  @Dependency(\.logger) var logger

  private enum CancelID { case loadData }

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .onAppear:
        state.isLoading = true
        return .merge(
          .run { send in
            var items: [KeychainItem] = []
            if let token = try await keychainClient.getJwtToken() {
              items.append(KeychainItem(name: "Token", displayValue: token, itemType: .token))
            }
            if let userData = try? await keychainClient.getUserData() {
              items.append(KeychainItem(name: "UserData", displayValue: "\(userData.firstName) \(userData.lastName) (\(userData.email))", itemType: .userData))
            }
            if let deviceData = try await keychainClient.getDeviceData() {
              items.append(KeychainItem(name: "DeviceData", displayValue: deviceData.endpointArn, itemType: .deviceData))
            }
            let expiresAt = try? await keychainClient.getTokenExpiresAt()
            await send(.tokenExpirationLoaded(expiresAt))
            await send(.keychainItemsLoaded(items))
          }
          .cancellable(id: CancelID.loadData),
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
            logger.warning(.performance, "Failed to load metrics: \(error)")
          }
        }

      case let .metricsLoaded(metrics):
        state.downloadCount = metrics.downloadCount
        state.totalStorageBytes = metrics.totalStorageBytes
        state.playCount = metrics.playCount
        return .none

      case let .tokenExpirationLoaded(expiresAt):
        state.tokenExpiresAt = expiresAt
        return .none

      case .deleteTokenExpiration:
        return .run { send in
          try await keychainClient.deleteTokenExpiresAt()
          await send(.tokenExpirationUpdated)
        }

      case .setTokenExpiringSoon:
        let expiringSoon = Date().addingTimeInterval(2 * 60)
        return .run { [expiringSoon] send in
          try await keychainClient.setTokenExpiresAt(expiringSoon)
          await send(.tokenExpirationUpdated)
        }

      case .tokenExpirationUpdated:
        return .run { send in
          let expiresAt = try? await keychainClient.getTokenExpiresAt()
          await send(.tokenExpirationLoaded(expiresAt))
        }

      case .signOutButtonTapped:
        state.isLoading = true
        return .run { send in
          try? await serverClient.logoutUser()
          try? await keychainClient.deleteJwtToken()
          try? await keychainClient.deleteTokenExpiresAt()
          await send(.signOutCompleted)
        }

      case .signOutCompleted:
        state.isLoading = false
        return .send(.delegate(.signedOut))
      }
    }
    .ifLet(\.$alert, action: \.alert)
  }
}
