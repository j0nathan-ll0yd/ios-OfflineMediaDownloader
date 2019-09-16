import Foundation
import Combine
import AVKit
import SwiftUI

final class FileCellViewModel: ObservableObject, Identifiable {
    @Published public var file: File
    @Published public var progress: Int = 0
    @Published public var isDownloaded: Bool = false
    @Published public var isDownloading: Bool = false
    private var observation: NSKeyValueObservation?
    private var location: URL
    private let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    
    private lazy var task: URLSessionDownloadTask = {
        let session = URLSession.shared
        let task = session.downloadTask(with: self.file.fileUrl) { (tempLocation, _, _) in
            debugPrint("file saved to: \(String(describing: tempLocation))")
            debugPrint("saving to: \(String(describing: self.location))")
            self.location = tempLocation!
            DispatchQueue.main.async{
                self.isDownloaded = true
                self.isDownloading = false
            }
        }
        return task
    }()
    
    public init(file: File) {
        self.file = file
        self.location = self.documentsPath.appendingPathComponent(file.fileUrl.lastPathComponent)
        
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
    
    public func play() {
        // TODO: Figure out how to launch a SwiftUI
        let player = AVPlayer(url: self.location)
        let playerController = AVPlayerViewController()
        playerController.modalPresentationStyle = .fullScreen
        //self.present(vc, animated: true, completion: nil)

        playerController.player = player
        //self.addChildViewController(playerController)
        //self.view.addSubview(playerController.view)
        //playerController.view.frame = self.view.frame

        player.play()
    }
}
