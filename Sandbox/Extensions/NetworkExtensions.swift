import Foundation
import Combine

struct DataTaskSubscription: Subscription {
    let task: URLSessionTask
    let combineIdentifier: CombineIdentifier
    
    func request(_ demand: Subscribers.Demand) {
    }
    
    func cancel() {
        task.cancel()
    }
}

struct DataTaskPublisher: Publisher {
    let session: URLSession
    let request: URLRequest
    
    public typealias Output = (data: Data, response: URLResponse)
    public typealias Failure = URLError
    
    public func receive<S>(subscriber: S) where S : Subscriber, Failure == S.Failure, Output == S.Input {
        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                assert(error is URLError)
                subscriber.receive(completion: .failure(error as! URLError))
                return
            }
            _ = subscriber.receive((data!, response!))
            subscriber.receive(completion: .finished)
        }
        let subscription = DataTaskSubscription(task: task, combineIdentifier: CombineIdentifier())
        subscriber.receive(subscription: subscription)
        task.resume()
    }
}

extension URLSession {
    func dataTaskPublisher(for request: URLRequest) -> DataTaskPublisher {
        DataTaskPublisher(session: self, request: request)
    }
}
