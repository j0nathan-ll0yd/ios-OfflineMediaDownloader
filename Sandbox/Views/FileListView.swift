import SwiftUI

let kPreviewBackground = Color(red: 237/255.0, green: 85/255.0, blue: 101/255.0)

struct FileListView: View {
    @ObservedObject var viewModel: FileListViewModel
    @Environment(\.managedObjectContext) var managedObjectContext
    @FetchRequest(fetchRequest: File.allIdeasFetchRequest()) var files: FetchedResults<File>

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
                    List(self.files) { file in
                        Text(file.key)
                    }.navigationBarTitle(Text("Files"))
                }
            }
        }
    }
}
