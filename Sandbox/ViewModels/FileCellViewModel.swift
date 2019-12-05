import Foundation
import Combine
import SwiftUI
import os

final class FileCellViewModel: ObservableObject, Identifiable {
    @Published public var file: File
    @Published public var progress: Int = 0
    @Published public var isDownloaded: Bool = false
    @Published public var isDownloading: Bool = false
    private var observation: NSKeyValueObservation?
    @Published public var location: URL
    private let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    
    private lazy var task: URLSessionDownloadTask = {
        let session = URLSession.shared
        debugPrint("Downloading \(self.file.fileUrl)")
        let task = session.downloadTask(with: self.file.fileUrl) { (tempLocalUrl, response, error) in
            debugPrint("file saved to: \(String(describing: tempLocalUrl))")
            debugPrint("saving to: \(String(describing: self.location))")
            
            if let tempLocalUrl = tempLocalUrl, error == nil {
                if let statusCode = (response as? HTTPURLResponse)?.statusCode {
                    print("Successfully downloaded. Status code: \(statusCode)")
                }
                
                do {
                    try FileManager.default.copyItem(at: tempLocalUrl, to: self.location)
                } catch (let writeError) {
                    print("Error creating a file \(self.location) : \(writeError)")
                }
                
            } else {
                print("Error took place while downloading a file. Error description: %@", error?.localizedDescription);
            }

            
            DispatchQueue.main.async{
                self.isDownloaded = true
                self.isDownloading = false
            }
        }
        return task
    }()
    
    public init(file: File, isDownloaded: Bool = false) {
        self.file = file
        self.isDownloaded = isDownloaded
        self.location = self.documentsPath.appendingPathComponent(file.fileUrl.lastPathComponent)
        if FileManager.default.fileExists(atPath: self.location.path) {
            self.isDownloaded = true
        }
    }
    
    public func download() {
        self.isDownloading = true
        self.observation = self.task.progress.observe(\.fractionCompleted) { (progress, _) in
            DispatchQueue.main.async{
                self.progress = Int(progress.fractionCompleted * 100)
            }
        }
        self.task.resume()
    }
    public func delete() {
        if FileManager.default.fileExists(atPath: self.location.path) {
            do {
                try FileManager.default.removeItem(atPath: self.location.path)
            } catch (let deleteError) {
                print("Error deleting a file \(self.location) : \(deleteError)")
            }
        }
    }
}
