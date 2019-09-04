import Foundation
import Combine
import SwiftUI

final class FileCellViewModel: NSObject, BindableObject, URLSessionDownloadDelegate {
    let didChange = PassthroughSubject<FileCellViewModel, Never>()
    
    public var file: File
    public var progress: Float = 0.0
    private var isCompleted: Bool = false
    private var isDownloading: Bool = false
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        debugPrint("Download finished: \(location)")
        try? FileManager.default.removeItem(at: location)
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        debugPrint("Task completed: \(task), error: \(error)")
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        
        if totalBytesExpectedToWrite > 0 {
            let progress = Float(totalBytesWritten) / Float(totalBytesExpectedToWrite)
            DispatchQueue.main.async {
                self.progress = progress
                self.didChange.send(self)
            }
            debugPrint("Progress \(downloadTask) \(progress)")
            
        }
    }
    
    private lazy var urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        // Uncommenting the line below out will cause this to not work
        //let config = URLSessionConfiguration.background(withIdentifier: "MySession")
        config.isDiscretionary = true
        config.sessionSendsLaunchEvents = true
        
        debugPrint("Session identifier: \(config.identifier)")
        
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()
    
    public init(file: File) {
        self.file = file
    }
    
    public func download() {
        debugPrint("Downloading...")
        debugPrint(self.file.fileUrl.absoluteString)
        
        
        let task = self.urlSession.downloadTask(with: self.file.fileUrl)
        task.resume()
        
    }
    
    public func getProgress() -> String {
        return String(format: "%2.4f", self.progress)
    }
}

/*
 
 let assembledURL = String("https://api.github.com/users/\(username)")
 let publisher = URLSession.shared.dataTaskPublisher(for: URL(string: assembledURL)!)
 .handleEvents(receiveSubscription: { _ in
 networkActivityPublisher.send(true)
 }, receiveCompletion: { _ in
 networkActivityPublisher.send(false)
 }, receiveCancel: {
 networkActivityPublisher.send(false)
 })
 .tryMap { data, response -> Data in
 guard let httpResponse = response as? HTTPURLResponse,
 httpResponse.statusCode == 200 else {
 throw APIFailureCondition.invalidServerResponse
 }
 return data
 }
 .decode(type: GithubAPIUser.self, decoder: JSONDecoder())
 .map {
 [$0]
 }
 .catch { err in
 // return Publishers.Empty<GithubAPIUser, Never>()
 // ^^ when I originally wrote this method, I was returning
 // a GithubAPIUser? optional, and then a GithubAPIUser without
 // optional. I ended up converting this to return an empty
 // list as the "error output replacement" so that I could
 // represent that the current value requested didn't *have* a
 // correct github API response. When I was returing a single
 // specific type, using Publishers.Empty was a good way to do a
 // "no data on failure" error capture scenario.
 return Just([])
 }
 .eraseToAnyPublisher()
 return publisher
 */

/*
 https://www.hackingwithswift.com/example-code/networking/how-to-download-files-with-urlsession-and-downloadtask
 let url = URL(string: "https://www.apple.com")!
 
 let task = URLSession.shared.downloadTask(with: url) { localURL, urlResponse, error in
 if let localURL = localURL {
 if let string = try? String(contentsOf: localURL) {
 print(string)
 }
 }
 }
 
 task.resume()
 */

/*
 let url = URL(string: "https://speed.hetzner.de/100MB.bin")!
 let task = URLSession.shared.downloadTask(with: url, completionHandler: { (tempURL, response, error) in
 debugPrint("finished fetching \(url.absoluteString)")
 debugPrint("finished fetching \(tempURL)")
 debugPrint("finished fetching \(response)")
 })
 
 let observation = task.progress.observe(\.fractionCompleted) { progress, _ in
 debugPrint("Observing progress")
 debugPrint(progress.fractionCompleted)
 }
 
 task.resume()
 */
