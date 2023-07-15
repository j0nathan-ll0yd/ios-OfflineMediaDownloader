import SwiftUI
import Combine
import NotificationCenter

final class FileListViewModel: ObservableObject, Identifiable {
  @Published var dataSource: [FileCellViewModel] = []
  @Published var pendingFileIds: [String] = []
  @Published var isLoading: Bool = false
  private var cancellableSink: Cancellable?
  
  init() {
    NotificationCenter.default.addObserver(
      self,
      selector:#selector(fileDownloaded(_:)),
      name: Notification.Name("com.publisher.combine"),
      object: nil
    )
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
    
    let youTubeVideoId = fileUrl.absoluteString.youtubeID
    guard youTubeVideoId != nil else {
      print("Not a valid YouTube URL")
      return
    }
    
    self.isLoading = true
    self.cancellableSink = Server.addFile(url: fileUrl).sink(
      receiveCompletion: { completion in
        self.isLoading = false
        if case .failure(let err) = completion {
          debugPrint(completion)
          print("Retrieving data failed with error \(err)")
        }
      },
      receiveValue: { fileResponse in
        print("Added file")
        self.pendingFileIds.append(youTubeVideoId!)
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
    self.isLoading = true
    self.cancellableSink = Server.getFiles().sink(
      receiveCompletion: { completion in
        self.isLoading = false
        if case .failure(let err) = completion {
          print("Retrieving data failed with error \(err)")
        }
      },
      receiveValue: { fileResponse in
        CoreDataHelper.saveFiles()
        self.removePendingFilesAlreadyAvailable()
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
  // Compares local store with what's pending
  func removePendingFilesAlreadyAvailable() {
    print("removePendingFilesAlreadyAvailable")
    let files = CoreDataHelper.getFiles()
    let fileIds = Set(files.map { $0.fileId })
    debugPrint(fileIds)
    let pendingFileIds = Set(self.pendingFileIds)
    debugPrint(pendingFileIds)
    let newPendingFileIds = Array(pendingFileIds.subtracting(fileIds))
    debugPrint(newPendingFileIds)
    self.pendingFileIds = newPendingFileIds
  }
  
  
  @objc func fileDownloaded(_ notification: Notification) {
    print("fileDownloaded \(notification)")
    let event = notification.userInfo!["event"]
    if (event is BackgroundDownloadComplete || event is RegistrationComplete || event is LoginComplete) {
      DispatchQueue.main.async { self.searchRemote() }
    }
  }
}
