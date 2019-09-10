//
//  DownloadService.swift
//  Sandbox
//
//  Created by Jonathan Lloyd on 9/8/19.
//  Copyright © 2019 Jonathan Lloyd. All rights reserved.
//

import Foundation
import Combine

enum WeatherError: Error {
  case parsing(description: String)
  case network(description: String)
}

protocol WeatherFetchable {
  func forecast(
    with components: URLComponents
  ) -> AnyPublisher<Data, WeatherError>
}

class DownloadService {
  private let session: URLSession
  
  init(session: URLSession = .shared) {
    self.session = session
  }
}

extension DownloadService: WeatherFetchable {
    
    func forecast<T>(
      with components: URLComponents
    ) -> AnyPublisher<T, WeatherError> where T: Decodable {
      // 1
      guard let url = components.url else {
        let error = WeatherError.network(description: "Couldn't create URL")
        return Fail(error: error).eraseToAnyPublisher()
      }

      // 2
      return session.dataTaskPublisher(for: URLRequest(url: url))
        // 3
        .mapError { error in
          .network(description: error.localizedDescription)
        }
        // 4
        //.flatMap(maxPublishers: .max(1)) { pair in
          //decode(pair.data)
        //}
        // 5
        .eraseToAnyPublisher()
    }
}
