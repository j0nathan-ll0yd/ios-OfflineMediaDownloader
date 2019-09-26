import SwiftUI

struct FileListView: View {
    @ObservedObject var viewModel: FileListViewModel

    init(viewModel: FileListViewModel) {
      self.viewModel = viewModel
    }
    
    var body: some View {
        VStack {
            List {
              ForEach(viewModel.dataSource, content: FileCellView.init(viewModel:))
            }
        }
    }
}
