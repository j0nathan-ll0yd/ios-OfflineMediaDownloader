//
//  URLSession.swift
//  Sandbox
//
//  Created by Jonathan Lloyd on 9/14/19.
//  Copyright © 2019 Jonathan Lloyd. All rights reserved.
//

import Foundation
import Combine

enum Either<Left, Right> {
    case left(Left)
    case right(Right)

    var left: Left? {
        switch self {
        case let .left(value):
            return value
        case .right:
            return nil
        }
    }

    var right: Right? {
        switch self {
        case let .right(value):
            return value
        case .left:
            return nil
        }
    }
}

extension URLSession {
    func dataTaskPublisherWithProgress(for url: URL) -> AnyPublisher<Either<Progress, (data: Data, response: URLResponse)>, URLError> {
        
        typealias TaskEither = Either<Progress, (data: Data, response: URLResponse)>
        
        let completion = PassthroughSubject<(data: Data, response: URLResponse), URLError>()
        
        let task = dataTask(with: url) { data, response, error in
            if let data = data, let response = response {
                completion.send((data, response))
                completion.send(completion: .finished)
            } else if let error = error as? URLError {
                completion.send(completion: .failure(error))
            } else {
                fatalError("This should be unreachable, something is clearly wrong.")
            }

        }
        
        task.resume()
        
        
        return task.publisher(for: \.progress.completedUnitCount)
            .compactMap { [weak task] _ in task?.progress }
            .setFailureType(to: URLError.self)
            .map(TaskEither.left)
            .merge(with: completion.map(TaskEither.right))
            .eraseToAnyPublisher()
    }
}
