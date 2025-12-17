
import Foundation
import ComposableArchitecture
import UIKit

private func generateRequest(pathPart: String, method: String = "POST") async throws -> URLRequest {
  @Dependency(\.keychainClient) var keychainClient

  var urlComponents = URLComponents(string: Environment.basePath+pathPart)!
  urlComponents.queryItems = [
    URLQueryItem(name: "ApiKey", value: Environment.apiKey)
  ]

  var request = URLRequest(url: urlComponents.url!)
  request.httpMethod = method
  request.addValue("application/json", forHTTPHeaderField: "Content-Type")

  if let token = try? await keychainClient.getJwtToken() {
    let tokenPreview = String(token.prefix(20)) + "..." + String(token.suffix(10))
    print("🔑 Token found (\(token.count) chars): \(tokenPreview)")
    request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
  } else {
    print("🔑 No authorization token found in keychain")
  }
  return request
}

@DependencyClient
struct ServerClient {
  var registerDevice: @Sendable (_ token: String) async throws -> RegisterDeviceResponse
  var registerUser: @Sendable (_ userData: UserData, _ idToken: String) async throws -> LoginResponse
  var loginUser: @Sendable (_ idToken: String) async throws -> LoginResponse
  var getFiles: @Sendable () async throws -> FileResponse
  var addFile: @Sendable (_ url: URL) async throws -> DownloadFileResponse
}

extension DependencyValues {
  var serverClient: ServerClient {
    get { self[ServerClient.self] }
    set { self[ServerClient.self] = newValue }
  }
}

enum ServerClientError: Error, Equatable {
  case internalServerError(message: String)
  case unauthorized
}

extension ServerClientError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .internalServerError(let message):
            return NSLocalizedString(message, comment: "My error")
        case .unauthorized:
            return NSLocalizedString("Session expired - please login again", comment: "Unauthorized error")
        }
    }
}

/// Check HTTP response for 401/403 and throw unauthorized error
private func checkUnauthorized(_ response: URLResponse) throws {
  if let httpResponse = response as? HTTPURLResponse {
    if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
      print("🔒 Unauthorized response: HTTP \(httpResponse.statusCode)")
      throw ServerClientError.unauthorized
    }
  }
}

extension ServerClient: DependencyKey {
  static let liveValue = ServerClient(
    registerDevice: { token in
      print("📡 ServerClient.registerDevice called")
      let parameters = await [
          "token": token,
          "deviceId": UIDevice.current.identifierForVendor!.uuidString,
          "name": UIDevice.current.name,
          "systemName": UIDevice.current.systemName,
          "systemVersion": UIDevice.current.systemVersion
      ] as [String : Any]
      #if DEBUG
      debugPrint(parameters)
      #endif
      var request = try await generateRequest(pathPart: "registerDevice", method: "POST")
      #if DEBUG
      debugPrint(request)
      #endif
      let jsonData = try? JSONSerialization.data(withJSONObject: parameters)
      request.httpBody = jsonData
      #if DEBUG
      debugPrint(jsonData!.prettyPrintedJSONString!)
      #endif
      let (data, response) = try await URLSession.shared.data(for: request)
      if let httpResponse = response as? HTTPURLResponse {
        print("📡 ServerClient.registerDevice HTTP status: \(httpResponse.statusCode)")
      }
      try checkUnauthorized(response)
      #if DEBUG
      debugPrint(data.prettyPrintedJSONString!)
      #endif
      let registerDeviceResponse = try jsonDecoder.decode(RegisterDeviceResponse.self, from: data)
      if let error = registerDeviceResponse.error {
        if error.message.contains("not authorized") || error.message.contains("Unauthenticated") {
          throw ServerClientError.unauthorized
        }
        throw ServerClientError.internalServerError(message: error.message)
      }
      return registerDeviceResponse
    },
    registerUser: { userData, idToken in
      print("📡 ServerClient.registerUser called")
      let parameters = [
        "idToken": idToken,
        "firstName": userData.firstName,
        "lastName": userData.lastName
      ] as [String : Any]
      #if DEBUG
      debugPrint(parameters)
      #endif
      var request = try await generateRequest(pathPart: "registerUser", method: "POST")
      #if DEBUG
      debugPrint(request)
      #endif
      let jsonData = try? JSONSerialization.data(withJSONObject: parameters)
      request.httpBody = jsonData
      #if DEBUG
      debugPrint(jsonData!.prettyPrintedJSONString!)
      #endif
      let (data, _) = try await URLSession.shared.data(for: request)
      #if DEBUG
      debugPrint(data.prettyPrintedJSONString!)
      #endif
      let loginResponse = try jsonDecoder.decode(LoginResponse.self, from: data)
      if loginResponse.error != nil {
        throw ServerClientError.internalServerError(message: loginResponse.error!.message)
      }
      return loginResponse
    },
    loginUser: { idToken in
      print("📡 ServerClient.loginUser called")
      let parameters = ["idToken": idToken] as [String : Any]
      #if DEBUG
      debugPrint(parameters)
      #endif
      var request = try await generateRequest(pathPart: "login", method: "POST")
      #if DEBUG
      debugPrint(request)
      #endif
      let jsonData = try? JSONSerialization.data(withJSONObject: parameters)
      request.httpBody = jsonData
      #if DEBUG
      debugPrint(jsonData!.prettyPrintedJSONString!)
      #endif
      let (data, _) = try await URLSession.shared.data(for: request)
      #if DEBUG
      debugPrint(data.prettyPrintedJSONString!)
      #endif
      let loginResponse = try jsonDecoder.decode(LoginResponse.self, from: data)
      if loginResponse.error != nil {
        throw ServerClientError.internalServerError(message: loginResponse.error!.message)
      }
      return loginResponse
    },
    getFiles: {
      print("📡 ServerClient.getFiles called")
      var request = try await generateRequest(pathPart: "files", method: "GET")
      #if DEBUG
      debugPrint(request)
      #endif
      let (data, response) = try await URLSession.shared.data(for: request)
      if let httpResponse = response as? HTTPURLResponse {
        print("📡 ServerClient.getFiles HTTP status: \(httpResponse.statusCode)")
      }
      try checkUnauthorized(response)
      #if DEBUG
      debugPrint(data.prettyPrintedJSONString!)
      #endif
      let fileResponse = try jsonDecoder.decode(FileResponse.self, from: data)
      if let error = fileResponse.error {
        // Check if this is an auth-related error in the body
        if error.message.contains("not authorized") || error.message.contains("Unauthenticated") {
          throw ServerClientError.unauthorized
        }
        throw ServerClientError.internalServerError(message: error.message)
      }
      return fileResponse
    },
    addFile: { url in
      print("📡 ServerClient.addFile called with URL: \(url)")
      let parameters = ["articleURL": url.absoluteString] as [String: Any]
      #if DEBUG
      debugPrint(parameters)
      #endif
      var request = try await generateRequest(pathPart: "feedly", method: "POST")
      #if DEBUG
      debugPrint(request)
      #endif
      let jsonData = try? JSONSerialization.data(withJSONObject: parameters)
      request.httpBody = jsonData
      let (data, response) = try await URLSession.shared.data(for: request)
      if let httpResponse = response as? HTTPURLResponse {
        print("📡 ServerClient.addFile HTTP status: \(httpResponse.statusCode)")
      }
      try checkUnauthorized(response)
      #if DEBUG
      debugPrint("📡 ServerClient.addFile response:")
      debugPrint(data.prettyPrintedJSONString!)
      #endif
      let fileResponse = try jsonDecoder.decode(DownloadFileResponse.self, from: data)
      if let error = fileResponse.error {
        // Check if this is an auth-related error in the body
        if error.message.contains("not authorized") || error.message.contains("Unauthenticated") {
          throw ServerClientError.unauthorized
        }
        throw ServerClientError.internalServerError(message: error.message)
      }
      return fileResponse
    }
  )
}

private let jsonDecoder: JSONDecoder = {
  let decoder = JSONDecoder()
  let formatter = DateFormatter()
  formatter.calendar = Calendar(identifier: .iso8601)
  formatter.dateFormat = "yyyy-MM-dd"
  formatter.timeZone = TimeZone(secondsFromGMT: 0)
  formatter.locale = Locale(identifier: "en_US_POSIX")
  decoder.dateDecodingStrategy = .formatted(formatter)
  return decoder
}()

// MARK: - Test/Preview implementation
extension ServerClient {
  static let testValue = ServerClient(
    registerDevice: { _ in
      RegisterDeviceResponse(
        body: EndpointResponse(endpointArn: "test-endpoint-arn"),
        error: nil,
        requestId: "test-request-id"
      )
    },
    registerUser: { _, _ in
      LoginResponse(
        body: TokenResponse(token: "test-jwt-token", expiresAt: nil, sessionId: nil, userId: nil),
        error: nil,
        requestId: "test-request-id"
      )
    },
    loginUser: { _ in
      LoginResponse(
        body: TokenResponse(token: "test-jwt-token", expiresAt: nil, sessionId: nil, userId: nil),
        error: nil,
        requestId: "test-request-id"
      )
    },
    getFiles: {
      FileResponse(
        body: FileList(contents: [], keyCount: 0),
        error: nil,
        requestId: "test-request-id"
      )
    },
    addFile: { _ in
      DownloadFileResponse(
        body: DownloadFileResponseDetail(status: "queued"),
        error: nil,
        requestId: "test-request-id"
      )
    }
  )
}
