import SwiftUI
import Combine

final class FileListViewModel: BindableObject {
    var didChange = PassthroughSubject<FileListViewModel, Never>()
    var files = [File]() {
        didSet { didChange.send(self) }
    }
    
    init() {
        search()
    }
    
    func search() {
            
        let file1 = File(key: "Short video", lastModified: Date(), eTag: "eTag", size: 3485113, storageClass: "STANDARD", fileUrl: URL(string: "https://kevin-and-bean-archive.s3.amazonaws.com/01%20Opening%20Segment-2018-04-10.mp3")!)
        let file2 = File(key: "This is a video with a really long name to see how the sizing works for this text", lastModified: Date.init(timeInterval: -186400, since: Date()), eTag: "eTag", size: 3485113, storageClass: "STANDARD", fileUrl: URL(string: "https://kevin-and-bean-archive.s3.amazonaws.com/02%20Getting%20A%20Tattoo%20As%20A%20Payoff%20For%20A%20Bet-2018-02-02-Listener%20Call-in.mp3")!)
        
        self.files = [file1, file2]
    }
    
    func download(file: File) {
        debugPrint("Downloading...")
        debugPrint(file)
        self.files = self.files.shuffled()
    }
}
