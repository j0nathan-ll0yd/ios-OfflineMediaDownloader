import SwiftUI

let kPreviewBackground = Color(red: 237/255.0, green: 85/255.0, blue: 101/255.0)
struct FileListView: View {
  @ObservedObject var fileListViewModel: FileListViewModel
  @ObservedObject var mainViewModel: MainViewModel
  @State private var showActionSheet = false
  @State private var isAnimating = false
  let animation = Animation.linear.repeatForever(autoreverses: false).speed(0.5)

  init(fileListViewModel: FileListViewModel, mainViewModel: MainViewModel) {
    self.fileListViewModel = fileListViewModel
    self.mainViewModel = mainViewModel
  }
  
  private func handleAddFromClipboard() -> URL? {
    let pasteboard = UIPasteboard.general
    guard let urlString = pasteboard.string else {
      print("Clipboard is empty")
      return nil
    }
    guard let url = URL(string: urlString) else {
      print("Text is not valid URL")
      return nil
    }
    return url
  }
  
  var body: some View {
    LoadingView(isShowing: $fileListViewModel.isLoading) {
      VStack {
        NavigationView {
          List(self.fileListViewModel.dataSource) { fileCellViewModel in
            FileCellView(viewModel: fileCellViewModel)
          }
          .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            self.fileListViewModel.searchLocal()
          }
          .navigationBarTitle(Text("Files"))
          .navigationBarItems(trailing:
            HStack {
              if (self.fileListViewModel.pendingFileIds.count > 0) {
                NavigationLink {
                  PendingFileView(fileIds: self.fileListViewModel.pendingFileIds)
                } label: {
                  Label("Pending", systemImage: "hourglass.circle")
                    .rotationEffect(.degrees(isAnimating ? 360 : 0))
                    .onAppear {
                      print("Spinner appeared")
                      print(isAnimating)
                      DispatchQueue.main.async {
                        withAnimation(animation) {
                          isAnimating = true
                        }
                      }
                    }.onDisappear {
                      print("Spinner disappeared")
                      print(isAnimating)
                    }
                }
              }
              Button(action: { self.fileListViewModel.searchRemote() }) {
                Label("Refresh", systemImage: "arrow.clockwise.circle")
              }
              Button(action: {
                if mainViewModel.registrationStatus == .unregistered {
                  EventHelper.emit(event: PromptRegistration())
                } else {
                  self.showActionSheet = true
                }
              }) {
                Label("Add", systemImage: "plus.circle")
              }.confirmationDialog(
                Text("Hello"),
                isPresented: $showActionSheet
              ) {
                if UIPasteboard.general.hasStrings {
                  Button("From Clipboard", role: .destructive) {
                    self.fileListViewModel.addItem(url: self.handleAddFromClipboard())
                  }
                }
                Button("Cancel", role: .cancel) {
                  showActionSheet = false
                }
              }
            }
          )
        }
      }
    }
  }
}

#if DEBUG
struct FileListViewView_Previews: PreviewProvider {
  static var previews: some View {
    let fileListViewModel: FileListViewModel = FileListViewModel()
    let mainViewModel: MainViewModel = MainViewModel()
    FileListView(fileListViewModel: fileListViewModel, mainViewModel: mainViewModel)
  }
}
#endif
