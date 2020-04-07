import SwiftUI
import Combine

final class FileListViewModel: ObservableObject, Identifiable {
    @Published var dataSource: [FileCellViewModel] = []
    @Environment(\.managedObjectContext) var managedObjectContext
    @Published var isLoading: Bool = false
    
    private var subscription: Cancellable?
    private let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    
    init() {
        searchRemote()
    }
    init(datasource: [FileCellViewModel], isLoading: Bool) {
        self.dataSource = datasource
        self.isLoading = isLoading
    }
    
    func deleteItems(at offsets: IndexSet) {
        debugPrint("Deleting \(offsets)")
        guard let index = Array(offsets).first else { return }
        let fileCellViewModel: FileCellViewModel = dataSource[index]
        fileCellViewModel.delete()
        dataSource.remove(atOffsets: offsets)
    }
    
    func searchLocal() {
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: documentsPath, includingPropertiesForKeys: nil)
            fileURLs.map({ url in
                
            })
        } catch {
            print("Error while enumerating files \(documentsPath.path): \(error.localizedDescription)")
        }
    }
    
    func searchRemote() {
        var urlComponents = URLComponents(string: "https://m0l9d6rzcb.execute-api.us-west-2.amazonaws.com/Prod/files")!
        urlComponents.queryItems = [
            URLQueryItem(name: "ApiKey", value: "HPOlSPxiPY7mzvcfnxHPJ5i0UIr41xuO9099TB1e")
        ]
        
        var request = URLRequest(url: urlComponents.url!)
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let decoder = JSONDecoder()
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        let context = appDelegate.persistentContainer.viewContext
        decoder.userInfo[CodingUserInfoKey.context!] = context
        
        self.subscription = URLSession.shared
          .dataTaskPublisher(for: request)
          .map(\.data)
          .decode(type: FileResponse.self, decoder: decoder)
          .sink(receiveCompletion: { completion in
            if case .failure(let err) = completion {
              print("Retrieving data failed with error \(err)")
            }
          }, receiveValue: { object in
            print("Retrieved object \(object)")
            DispatchQueue.main.async {
                self.dataSource = object.body.contents.map({ file in
                    return FileCellViewModel(file: file)
                })
                do {
                    try context.save()
                    print("Saved new files.")
                }
                catch { fatalError("Unable to save data.") }
                self.isLoading = false
            }
          })
        
    }
}
