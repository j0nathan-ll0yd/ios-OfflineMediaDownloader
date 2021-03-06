import SwiftUI
import Combine

final class FileListViewModel: ObservableObject, Identifiable {
  @Published var dataSource: [FileCellViewModel] = []
  @Published var isLoading: Bool = false
  private var cancellableSink: Cancellable?
  
  init() {
    searchLocal()
  }
    
  init(datasource: [FileCellViewModel], isLoading: Bool) {
    self.dataSource = datasource
    self.isLoading = isLoading
  }
  
  func deleteItems(at offsets: IndexSet) {
    debugPrint("Deleting \(offsets)")
    guard let index = Array(offsets).first else { return }
    let fileCellViewModel: FileCellViewModel = dataSource[index]
    fileCellViewModel.delete()
    dataSource.remove(atOffsets: offsets)
  }
  
  func searchLocal() {
    let files = CoreDataHelper.getFiles()
    DispatchQueue.main.async {
      self.dataSource = files.map({ file in
        return FileCellViewModel(file: file)
      })
      self.isLoading = false
    }
  }
  
  func searchRemote() {
    self.cancellableSink = Server.getFiles().sink(
      receiveCompletion: { completion in
        if case .failure(let err) = completion {
          print("Retrieving data failed with error \(err)")
        }
      },
      receiveValue: { fileResponse in
        CoreDataHelper.saveFiles()
        DispatchQueue.main.async {
          self.isLoading = false
          self.dataSource = fileResponse.body.contents.map({ file in
            return FileCellViewModel(file: file)
          })
        }
      }
    )
  }
}
