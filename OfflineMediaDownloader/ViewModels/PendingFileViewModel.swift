import Foundation
import SwiftUI

final class PendingFileViewModel: ObservableObject {
  @StateObject private var store = UnencryptedDataStore()
  @Published var pendingFileIds: [String] = []
  
  init() {
    UnencryptedDataStore.load { result in
      switch result {
      case .failure(let error):
          fatalError(error.localizedDescription)
      case .success(let data):
        print("Loaded data from UnencryptedDataStore")
        self.pendingFileIds = data.pendingFileIds
      }
    }
  }

  func handleDelete(at offsets: IndexSet) {
    debugPrint("Deleting \(offsets)")
    guard let index = Array(offsets).first else { return }
    print(index)
  }
}
