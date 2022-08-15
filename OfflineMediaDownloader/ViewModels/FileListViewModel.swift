import SwiftUI
import Combine

final class FileListViewModel: ObservableObject, Identifiable {
  @Published var dataSource: [FileCellViewModel] = []
  @Published var isLoading: Bool = false
  private var cancellableSink: Cancellable?
  
  init() {
    //searchLocal()
    //searchRemote()
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
  
  func addItem(url: URL?) -> Void {
    debugPrint("addItem")
    guard let fileUrl = url else {
      print("Text is not valid URL")
      return
    }
    self.cancellableSink = Server.addFile(url: fileUrl).sink(
      receiveCompletion: { completion in
        if case .failure(let err) = completion {
          print("Retrieving data failed with error \(err)")
        }
      },
      receiveValue: { fileResponse in
        print("Added file")
        debugPrint(fileResponse)
      }
    )
  }
  
  func searchLocal() {
    print("FileListViewModel.searchLocal")
    let files = CoreDataHelper.getFiles()
    DispatchQueue.main.async {
      self.dataSource = files.map({ file in
        return FileCellViewModel(file: file)
      })
      self.isLoading = false
    }
  }
  
  func searchRemote() {
    print("FileListViewModel.searchRemote")
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
          if (fileResponse.body != nil) {
            self.dataSource = fileResponse.body!.contents.map({ file in
              return FileCellViewModel(file: file)
            })
          }
        }
      }
    )
  }
}
