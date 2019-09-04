//
//  SessionDelegateFactory.swift
//  Sandbox
//
//  Created by Jonathan Lloyd on 9/2/19.
//  Copyright © 2019 Jonathan Lloyd. All rights reserved.
//

import Foundation

final class SessionDelegateFactory: NSObject, URLSessionDownloadDelegate {
    typealias ProgressHandler = (Float, URLSessionDownloadTask) -> ()
    public var onProgress : ProgressHandler
    
    init(progressHandler: @escaping ProgressHandler) {
        self.onProgress = progressHandler
        super.init()
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        
        if totalBytesExpectedToWrite > 0 {
            let progress = Float(totalBytesWritten) / Float(totalBytesExpectedToWrite)
            self.onProgress(progress, downloadTask)
            debugPrint("Progress \(downloadTask) \(progress)")
            
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        debugPrint("Download finished: \(location)")
        try? FileManager.default.removeItem(at: location)
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        debugPrint("Task completed: \(task), error: \(error)")
    }
}
