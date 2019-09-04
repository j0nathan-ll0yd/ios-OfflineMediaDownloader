import Foundation

class Download {
    var isDownloading = false
    var progress: Float = 0
    var resumeData: Data?
    var task: URLSessionDownloadTask?
    var file: File
    
    init(file: File) {
        self.file = file
    }
}
