import SwiftUI

let kPreviewBackground = Color(red: 237/255.0, green: 85/255.0, blue: 101/255.0)

struct FileListView: View {
    @ObservedObject var viewModel: FileListViewModel

    init(viewModel: FileListViewModel) {
        self.viewModel = viewModel
    }
    
    var body: some View {
        HStack {
            if viewModel.isLoading {
                ZStack {
                    kPreviewBackground.edgesIgnoringSafeArea(.all)
                    VStack { ActivityIndicator().frame(width: 50, height: 50) }.foregroundColor(Color.white)
                }
            }
            else {
                NavigationView {
                    List {
                        ForEach(viewModel.dataSource, content: FileCellView.init(viewModel:))
                            .onDelete(perform: self.viewModel.deleteItems)
                    }.navigationBarTitle(Text("Files"))
                }
            }
        }
    }
}

#if DEBUG

let myLongFile = File(key: "This is a video with a really long name to see how the sizing works for this text", lastModified: Date.init(timeInterval: -186400, since: Date()), eTag: "eTag", size: 3485113, storageClass: "STANDARD", fileUrl: URL(string: "https://kevin-and-bean-archive.s3.amazonaws.com/02%20Getting%20A%20Tattoo%20As%20A%20Payoff%20For%20A%20Bet-2018-02-02-Listener%20Call-in.mp3")!)
let myShortFile = File(key: "word word word word word word word word word word", lastModified: Date.init(timeInterval: -186400, since: Date()), eTag: "eTag", size: 3485113, storageClass: "STANDARD", fileUrl: URL(string: "https://kevin-and-bean-archive.s3.amazonaws.com/02%20Getting%20A%20Tattoo%20As%20A%20Payoff%20For%20A%20Bet-2018-02-02-Listener%20Call-in.mp3")!)

let fileCellViewModel1 = FileCellViewModel(file: myLongFile, isDownloaded: false)
let fileCellViewModel2 = FileCellViewModel(file: myShortFile, isDownloaded: true)
let fileListViewModel = FileListViewModel(datasource: [fileCellViewModel1, fileCellViewModel2], isLoading: false)

struct FileListView_Previews : PreviewProvider {
    static var previews: some View {
        FileListView(viewModel: fileListViewModel)
    }
}
#endif
