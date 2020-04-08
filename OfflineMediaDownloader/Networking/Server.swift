
import Foundation
import Combine
import UIKit

enum Server {
  private static func generateRequest(pathPart: String, method:String = "POST") -> URLRequest {
    guard let apiKey = ProcessInfo.processInfo.environment["MEDIA_DOWNLOADER_API_KEY"] else {
        fatalError("No ENV key 'MEDIA_DOWNLOADER_API_KEY' specified")
    }
    guard let basePath = ProcessInfo.processInfo.environment["MEDIA_DOWNLOADER_BASE_PATH"] else {
        fatalError("No ENV key 'MEDIA_DOWNLOADER_BASE_PATH' specified")
    }
    
    var urlComponents = URLComponents(string: basePath+pathPart)!
    urlComponents.queryItems = [
        URLQueryItem(name: "ApiKey", value: apiKey)
    ]
    
    var request = URLRequest(url: urlComponents.url!)
    request.httpMethod = method
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
    return request
  }
  private static func decoder() -> JSONDecoder {
    let decoder = JSONDecoder()
    decoder.userInfo[CodingUserInfoKey.context!] = CoreDataHelper.managedContext()
    return decoder
  }
  static func getFiles() -> AnyPublisher<FileResponse, Error> {
    let request = generateRequest(pathPart: "files", method: "GET")
    return URLSession.shared
      .dataTaskPublisher(for: request)
      .map(\.data)
      .decode(type: FileResponse.self, decoder: Server.decoder())
      .receive(on: DispatchQueue.main) // 6
      .eraseToAnyPublisher()
  }
  static func registerDevice(token: String) -> AnyPublisher<Int, Error> {
    
    let parameters = [
        "token": token,
        "UUID": UIDevice.current.identifierForVendor!.uuidString,
        "name": UIDevice.current.name,
        "systemName": UIDevice.current.systemName,
        "systemVersion": UIDevice.current.systemVersion
    ] as [String : Any]
    debugPrint(parameters)
    
    var request = generateRequest(pathPart: "registerDevice", method: "POST")
    let jsonData = try? JSONSerialization.data(withJSONObject: parameters)
    request.httpBody = jsonData
    return URLSession.shared
      .dataTaskPublisher(for: request)
      .tryMap { result in
        if let httpResponse = result.response as? HTTPURLResponse {
          return httpResponse.statusCode
        }
        return 500
      }
      .receive(on: DispatchQueue.main) // 6
      .eraseToAnyPublisher()
  }
  static func logEvent(message: Data) -> AnyCancellable {
    var request = generateRequest(pathPart: "logEvent", method: "POST")
    request.httpBody = message
    print("logEvent")
    print(String(decoding: message, as: UTF8.self))
    return URLSession.shared.dataTaskPublisher(for: request)
      .tryMap { result in
        if let httpResponse = result.response as? HTTPURLResponse {
          return httpResponse.statusCode
        }
        return 500
      }
      .receive(on: DispatchQueue.main) // 6
      .sink(receiveCompletion: { _ in }, receiveValue: { print($0) })
  }
}
