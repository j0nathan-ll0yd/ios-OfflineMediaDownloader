import Foundation
import Combine

final class FileCellViewModel: ObservableObject, Identifiable {
    @Published public var file: File
    @Published public var progress: String = "0.0"
    private var disposables = Set<AnyCancellable>()
    
    public init(file: File) {
        self.file = file
    }
    
    public func download() {
        debugPrint("Downloading...")
        debugPrint(self.file.fileUrl.absoluteString)
        
        self.progress = "20.0"
        debugPrint(self.progress)
        self.file.key = "Test"
        
        // TODO: Figure out how to make this return an AnyCancellable so it can be cancelled
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
            })
            .sink(receiveCompletion: { completion in
                    debugPrint(".sink() received the completion", String(describing: completion))
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
}
