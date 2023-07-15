import Foundation
import SwiftUI

class AppData: NSObject, Codable {
  var pendingFileIds: [String] = []
  
  private enum CodingKeys: String, CodingKey {
    case pendingFileIds
  }
  
  init(data: AppData) {
    pendingFileIds = data.pendingFileIds
  }
  func update(from data: AppData) {
    pendingFileIds = data.pendingFileIds
  }
  required init(from decoder:Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    pendingFileIds = try values.decode([String].self, forKey: .pendingFileIds)
  }
}

class UnencryptedDataStore: ObservableObject {
    @Published var appData: AppData?
    
    private static func fileURL() throws -> URL {
        try FileManager.default.url(for: .documentDirectory,
                                       in: .userDomainMask,
                                       appropriateFor: nil,
                                       create: false)
            .appendingPathComponent("core.data")
    }
    
    static func load(completion: @escaping (Result<AppData, Error>)->Void) {
        DispatchQueue.global(qos: .background).async {
            do {
                let fileURL = try fileURL()
                guard let file = try? FileHandle(forReadingFrom: fileURL) else {
                    fatalError("Failed to load AppData")
                }
                let data = try JSONDecoder().decode(AppData.self, from: file.availableData)
                DispatchQueue.main.async {
                    completion(.success(data))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    static func save(data: AppData, completion: @escaping (Result<Int, Error>)->Void) {
        DispatchQueue.global(qos: .background).async {
            do {
                let data = try JSONEncoder().encode(data)
                let outfile = try fileURL()
                try data.write(to: outfile)
                DispatchQueue.main.async {
                    completion(.success(1))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
}
