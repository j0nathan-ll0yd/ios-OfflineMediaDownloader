
import Foundation
import Combine

enum Server {
    static let basePath = "https://oztga5jjx4.execute-api.us-west-2.amazonaws.com/Prod/"
}

extension Server {
  private static func generateRequest(pathPart: String, method:String = "POST") -> URLRequest {
    var urlComponents = URLComponents(string: basePath+pathPart)!
    urlComponents.queryItems = [
        URLQueryItem(name: "ApiKey", value: "pFM2pr7gdm8E0DU87uRk8160s36dl82zQH25Pt60")
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
}
