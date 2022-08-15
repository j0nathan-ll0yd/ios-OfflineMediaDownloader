import SwiftUI

let kPreviewBackground = Color(red: 237/255.0, green: 85/255.0, blue: 101/255.0)

struct FileListView: View {
  @ObservedObject var fileListViewModel: FileListViewModel
  @ObservedObject var mainViewModel: MainViewModel
  @State private var showingSheet = false

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
    HStack {
      if fileListViewModel.isLoading {
        ZStack {
          kPreviewBackground.edgesIgnoringSafeArea(.all)
          VStack { ActivityIndicator().frame(width: 50, height: 50) }.foregroundColor(Color.white)
        }
      }
      else {
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
                Button(action: { self.fileListViewModel.searchRemote() }) {
                  Label("Refresh", systemImage: "arrow.clockwise.circle")
                }
                Menu {
                  if UIPasteboard.general.hasStrings {
                    Button(action: { self.fileListViewModel.addItem(url: self.handleAddFromClipboard())}) {
                          Label("From Clipboard", systemImage: "doc.on.clipboard")
                      }
                  }
                }
                label: {
                    Label("Add", systemImage: "plus.circle")
                }
              }.onTapGesture {
                if mainViewModel.registrationStatus == .unregistered {
                  EventHelper.emit(event: PromptRegistration())
                }
              }
          )
        }
      }
    }
  }
}
