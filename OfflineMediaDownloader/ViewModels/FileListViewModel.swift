import SwiftUI
import Combine

final class FileListViewModel: ObservableObject, Identifiable {
  @Published var dataSource: [FileCellViewModel] = []
  @Published var isLoading: Bool = false
  private var subscription: Cancellable?
  
  init() {
    //searchRemote()
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
    self.subscription = Server.getFiles().sink(
      receiveCompletion: { completion in
        if case .failure(let err) = completion {
          print("Retrieving data failed with error \(err)")
        }
      },
      receiveValue: { object in
        print("Retrieved object \(object)")
        DispatchQueue.main.async {
          self.isLoading = false
          self.dataSource = object.body.contents.map({ file in
              return FileCellViewModel(file: file)
          })
        }
        CoreDataHelper.saveFiles()
      }
    )
  }
}
