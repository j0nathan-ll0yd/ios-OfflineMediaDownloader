import SwiftUI
import ComposableArchitecture

struct DiagnosticView: View {
  @Bindable var store: StoreOf<DiagnosticFeature>

  var body: some View {
    NavigationStack {
      List {
        Section(header: Text("Keychain Storage")) {
          if store.isLoading {
            ProgressView()
          } else if store.keychainItems.isEmpty {
            Text("No keychain items stored")
              .foregroundColor(.secondary)
          } else {
            ForEach(store.keychainItems) { item in
              NavigationLink(destination: KeychainDetailView(item: item)) {
                VStack(alignment: .leading, spacing: 4) {
                  Text(item.name)
                    .font(.headline)
                  Text(item.displayValue)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                }
              }
            }
            .onDelete { indexSet in
              store.send(.deleteKeychainItem(indexSet))
            }
          }
        }

        if store.showDebugActions {
          Section(header: Text("Debug Actions")) {
            Button(role: .destructive) {
              store.send(.truncateFilesButtonTapped)
            } label: {
              Label("Truncate All Files", systemImage: "trash")
            }
          }
        }
      }
      .navigationTitle("Account")
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button {
            store.send(.toggleDebugMode)
          } label: {
            Image(systemName: store.showDebugActions ? "wrench.fill" : "wrench")
          }
        }
      }
      .onAppear {
        store.send(.onAppear)
      }
    }
  }
}

struct KeychainDetailView: View {
  let item: KeychainItem

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        Text(item.name)
          .font(.title)
          .fontWeight(.bold)

        Text("Type: \(itemTypeName)")
          .font(.subheadline)
          .foregroundColor(.secondary)

        Divider()

        Text("Value:")
          .font(.headline)

        Text(item.displayValue)
          .font(.body)
          .textSelection(.enabled)

        Spacer()
      }
      .padding()
    }
    .navigationTitle(item.name)
    .navigationBarTitleDisplayMode(.inline)
  }

  private var itemTypeName: String {
    switch item.itemType {
    case .token:
      return "JWT Token"
    case .userData:
      return "User Data"
    case .deviceData:
      return "Device Data"
    }
  }
}

#Preview {
  DiagnosticView(store: Store(initialState: DiagnosticFeature.State()) {
    DiagnosticFeature()
  })
}
