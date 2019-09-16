import Foundation
import Combine
import AVKit
import SwiftUI

final class FileCellViewModel: ObservableObject, Identifiable {
    @Published public var file: File
    @Published public var progress: Int = 0
    @Published public var isDownloaded: Bool = false
    @Published public var isDownloading: Bool = false
    private var location: URL
    private var disposables = Set<AnyCancellable>()
    private let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!

    public init(file: File) {
        self.file = file
        self.location = self.documentsPath.appendingPathComponent(file.fileUrl.lastPathComponent)
        
    }
    
    public func download() {
        self.isDownloading = true
        URLSession.shared.dataTaskPublisher(for: self.file.fileUrl)
        .handleEvents(receiveSubscription: { (subscription) in
            print("Receive subscription")
        }, receiveOutput: { output in
            print("Received output: \(output)")
        }, receiveCompletion: { _ in
            print("Receive completion")
        }, receiveCancel: {
            print("Receive cancel")
        }, receiveRequest: { demand in
            print("Receive request: \(demand)")
            self.isDownloading = true
        })
        .sink(receiveCompletion: { completion in
                debugPrint(".sink() received the completion", String(describing: completion))
                DispatchQueue.main.async {
                    self.isDownloaded = true
                }
                switch completion {
                    case .finished:
                        break
                    case .failure(let anError):
                        print("received error: ", anError)
                }
        }, receiveValue: { someValue in
            debugPrint(".sink() received \(someValue)")
        })
        .store(in: &disposables)
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
