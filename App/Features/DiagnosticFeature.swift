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
  }

  enum Action {
    case onAppear
    case toggleDebugMode
    case keychainItemsLoaded([KeychainItem])
    case deleteKeychainItem(IndexSet)
    case keychainItemDeleted
    case truncateFilesButtonTapped
    case filesTruncated
  }

  @Dependency(\.keychainClient) var keychainClient
  @Dependency(\.coreDataClient) var coreDataClient

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .onAppear:
        state.isLoading = true
        return .run { send in
          var items: [KeychainItem] = []

          // Load JWT Token
          if let token = try await keychainClient.getJwtToken() {
            items.append(KeychainItem(
              name: "Token",
              displayValue: String(token.prefix(50)) + "...",
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
        }

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
          switch item.itemType {
          case .token:
            try await keychainClient.deleteJwtToken()
          case .userData:
            try await keychainClient.deleteUserData()
          case .deviceData:
            try await keychainClient.deleteDeviceData()
          }
          await send(.keychainItemDeleted)
        }

      case .keychainItemDeleted:
        return .none

      case .truncateFilesButtonTapped:
        return .run { send in
          try await coreDataClient.truncateFiles()
          await send(.filesTruncated)
        }

      case .filesTruncated:
        return .none
      }
    }
  }
}
