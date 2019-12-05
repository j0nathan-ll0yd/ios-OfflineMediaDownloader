import SwiftUI
import Combine

final class FileListViewModel: ObservableObject, Identifiable {
    @Published var dataSource: [FileCellViewModel] = []
    @Published var isLoading: Bool = true
    private var subscription: Cancellable?
    
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
    
    func searchRemote() {
        var urlComponents = URLComponents(string: "https://zc21p8daqc.execute-api.us-west-2.amazonaws.com/Prod/files")!
        urlComponents.queryItems = [
            URLQueryItem(name: "ApiKey", value: "pRauC0NteI2XM5zSLgDzDaROosvnk1kF1H0ID2zc")
        ]
        
        var request = URLRequest(url: urlComponents.url!)
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        self.subscription = URLSession.shared
          .dataTaskPublisher(for: request)
          .map(\.data)
          .decode(type: FileResponse.self, decoder: JSONDecoder())
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
                self.isLoading = false
            }
          })
        
    }
    
    func search() {
            
        let file1 = File(key: "Short video", lastModified: Date(), eTag: "eTag", size: 3485113, storageClass: "STANDARD", fileUrl: URL(string: "https://kevin-and-bean-archive.s3.amazonaws.com/Turo%20Commercial-NIqubRnYBQs.mp4")!)
        let file2 = File(key: "This is a video with a really long name to see how the sizing works for this text", lastModified: Date.init(timeInterval: -186400, since: Date()), eTag: "eTag", size: 3485113, storageClass: "STANDARD", fileUrl: URL(string: "https://p-events-delivery.akamaized.net/3004qzusahnbjppuwydgjzsdyzsippar/m3u8/hls_vod_mvp.m3u8")!)
        
        let fileCellViewModel1 = FileCellViewModel(file: file1)
        let fileCellViewModel2 = FileCellViewModel(file: file2)
        
        self.dataSource.append(fileCellViewModel1)
        self.dataSource.append(fileCellViewModel2)
    }
}
