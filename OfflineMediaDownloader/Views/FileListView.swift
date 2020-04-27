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
          List(self.viewModel.dataSource) { fileCellViewModel in
              FileCellView(viewModel: fileCellViewModel)
          }
          .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            self.viewModel.searchLocal()
          }
          .navigationBarTitle(Text("Files"))
          .navigationBarItems(trailing:
            Button(action: { self.viewModel.searchRemote() }) {
              HStack {
                Text("Refresh")
                Image(systemName: "arrow.clockwise.circle")
              }
            }
          )
        }
      }
    }
  }
}
