import Foundation
import Combine
import SwiftUI
import os

final class FileCellViewModel: ObservableObject, Identifiable {
  @Published public var file: File
  @Published public var isDownloaded: Bool = false
  @Published public var isDownloading: Bool = false
  @Published public var progress: Int = 0
  @Published public var location: URL
  private var observation: NSKeyValueObservation?
  private var session = (UIApplication.shared.delegate as! AppDelegate).session
  
  private lazy var task: URLSessionDownloadTask = {
    let task = session.downloadTask(with: file.url!)
    task.countOfBytesClientExpectsToReceive = file.size!.int64Value
    self.observation = task.progress.observe(\.fractionCompleted) { (progress, _) in
      print("Download progress \(String(Int(progress.fractionCompleted * 100)))")
      DispatchQueue.main.async{
        self.progress = Int(progress.fractionCompleted * 100)
        if (self.progress == 100) {
          self.isDownloading = false
          self.isDownloaded = true
        }
      }
    }
    return task
  }()
  
  public init(file: File) {
    self.file = file
    debugPrint(file)
    self.location = FileHelper.filePath(url: file.url!)
    if FileHelper.fileExists(file: file) {
      DispatchQueue.main.async {
        self.isDownloaded = true
      }
    }
  }
  
  public func download() {
    DispatchQueue.main.async {
      self.isDownloading = true
    }
    self.task.resume()
  }
  public func delete() {
    FileHelper.deleteFile(file: self.file)
  }
}
