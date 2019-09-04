import SwiftUI

struct ContentView : View {
    @ObjectBinding var viewModel = FileListViewModel()
    
    var body: some View {
        List(self.viewModel.files) { file in
            FileCellView(fileCellViewModel: FileCellViewModel(file: file))
        }
    }
}

#if DEBUG
struct ContentView_Previews : PreviewProvider {
    static var previews: some View {
        ContentView(viewModel: FileListViewModel())
    }
}
#endif
