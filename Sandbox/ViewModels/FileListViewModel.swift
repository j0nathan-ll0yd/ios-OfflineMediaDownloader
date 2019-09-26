import SwiftUI
import Combine

final class FileListViewModel: ObservableObject, Identifiable {
    @Published var dataSource: [FileCellViewModel] = []
    @Published var currentVideo: File?
    
    init() {
        search()
    }
    
    func search() {
            
        let file1 = File(key: "Short video", lastModified: Date(), eTag: "eTag", size: 3485113, storageClass: "STANDARD", fileUrl: URL(string: "https://kevin-and-bean-archive.s3.amazonaws.com/Turo%20Commercial-NIqubRnYBQs.mp4")!)
        let file2 = File(key: "This is a video with a really long name to see how the sizing works for this text", lastModified: Date.init(timeInterval: -186400, since: Date()), eTag: "eTag", size: 3485113, storageClass: "STANDARD", fileUrl: URL(string: "https://p-events-delivery.akamaized.net/3004qzusahnbjppuwydgjzsdyzsippar/m3u8/hls_vod_mvp.m3u8")!)
        
        let fileCellViewModel1 = FileCellViewModel(file: file1)
        let fileCellViewModel2 = FileCellViewModel(file: file2)
        
        self.dataSource.append(fileCellViewModel1)
        self.dataSource.append(fileCellViewModel2)
    }
}
