
import Foundation
import Combine
import UIKit

// TODO: Send 'Authorization' header with 'Bearer: jwt' once implemented
enum Server {
  private static var cancellableSink: Cancellable?
  private static func generateRequest(pathPart: String, method:String = "POST") -> URLRequest {
    var urlComponents = URLComponents(string: Environment.basePath+pathPart)!
    urlComponents.queryItems = [
      URLQueryItem(name: "ApiKey", value: Environment.apiKey)
    ]
    
    var request = URLRequest(url: urlComponents.url!)
    request.httpMethod = method
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
    
    let token = KeychainHelper.getToken()
    if token.decoded.count > 0 {
      request.addValue("Bearer \(token.decoded)", forHTTPHeaderField: "Authorization")
    }
    return request
  }
  private static func decoder() -> JSONDecoder {
    let decoder = JSONDecoder()
    decoder.userInfo[CodingUserInfoKey.context!] = CoreDataHelper.managedContext()
    return decoder
  }
  static func getFiles() -> AnyPublisher<FileResponse, Error> {
    let request = generateRequest(pathPart: "files", method: "GET")
    let sharedPublisher = URLSession.shared.dataTaskPublisher(for: request).share()
    cancellableSink = sharedPublisher.tryMap() { element -> () in
      let httpResponse = element.response as? HTTPURLResponse
      debugPrint(httpResponse)
      if httpResponse!.statusCode == 401 {
        //KeychainHelper.deleteToken()
        EventHelper.emit(event: PromptLogin())
      }
    }
    .receive(on: DispatchQueue.main)
    .sink(receiveCompletion: { _ in print ("sharedPublisher completion") },
                receiveValue: { print ("sharedPublisher receiveValue")})
    // have a common handler for deleting tokens
    return sharedPublisher
      .map(\.data)
      .decode(type: FileResponse.self, decoder: Server.decoder())
      .receive(on: DispatchQueue.main)
      .eraseToAnyPublisher()
  }
  static func registerDevice(token: String) -> AnyPublisher<RegisterDeviceResponse, Error> {
    
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
      .map(\.data)
      .decode(type: RegisterDeviceResponse.self, decoder: Server.decoder())
      .receive(on: DispatchQueue.main)
      .eraseToAnyPublisher()
  }
  static func registerUser(user: UserData, authorizationCode: String) -> AnyPublisher<RegisterUserResponse, Error> {
    
    let parameters = [
      "authorizationCode": authorizationCode,
      "firstName": user.firstName,
      "lastName": user.lastName
    ] as [String : Any]
    debugPrint(parameters)
    
    var request = generateRequest(pathPart: "registerUser", method: "POST")
    let jsonData = try? JSONSerialization.data(withJSONObject: parameters)
    request.httpBody = jsonData
    return URLSession.shared
      .dataTaskPublisher(for: request)
      .map(\.data)
      .decode(type: RegisterUserResponse.self, decoder: Server.decoder())
      .receive(on: DispatchQueue.main)
      .eraseToAnyPublisher()
  }
  static func loginUser(authorizationCode: String) -> AnyPublisher<LoginUserResponse, Error> {
    
    let parameters = ["authorizationCode": authorizationCode] as [String : Any]
    debugPrint(parameters)
    
    var request = generateRequest(pathPart: "login", method: "POST")
    let jsonData = try? JSONSerialization.data(withJSONObject: parameters)
    request.httpBody = jsonData
    return URLSession.shared
      .dataTaskPublisher(for: request)
      .tryMap { result in
        if let httpResponse = result.response as? HTTPURLResponse {
          debugPrint(httpResponse)
        }
        return result.data
      }
      .decode(type: LoginUserResponse.self, decoder: Server.decoder())
      .receive(on: DispatchQueue.main)
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
      .receive(on: DispatchQueue.main)
      .sink(receiveCompletion: { _ in }, receiveValue: { print($0) })
  }
  static func addFile(url: URL) -> AnyPublisher<Int, Error> {
    
    let parameters = ["articleURL": url.absoluteString] as [String : Any]
    debugPrint(parameters)
    var request = generateRequest(pathPart: "feedly", method: "POST")
    let jsonData = try? JSONSerialization.data(withJSONObject: parameters)
    debugPrint(jsonData)
    request.httpBody = jsonData
    return URLSession.shared
      .dataTaskPublisher(for: request)
      .tryMap { result in
        if let httpResponse = result.response as? HTTPURLResponse {
          return httpResponse.statusCode
        }
        return 500
      }
      .receive(on: DispatchQueue.main)
      .eraseToAnyPublisher()
  }
}
