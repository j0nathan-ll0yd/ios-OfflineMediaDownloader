import SwiftUI
import UIKit

struct FileCellViewBody : View {
  var file: File
  init(file: File) {
    self.file = file
  }
  var body: some View {
    VStack(alignment: .leading) {
      Text("\(file.key)")
        .font(.body)
        .lineLimit(5)
        .multilineTextAlignment(.leading)
      Text("\(file.relativeDate)")
        .font(.subheadline)
        .foregroundColor(.gray)
      Spacer()
    }
    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .topLeading).padding(5)
      
  }
}

struct FileCellView : View {
  @ObservedObject var viewModel: FileCellViewModel
  @State var showVideo: Bool = false
  
  init(viewModel: FileCellViewModel) {
    self.viewModel = viewModel
  }
  
  var body: some View {
    ZStack {
      HStack {
        Image(systemName: "film")
        FileCellViewBody(file: self.viewModel.file)
        if viewModel.isDownloaded {
          Button(action: { self.showVideo.toggle() }) {
            Image(systemName: "play.circle").sheet(
              isPresented: $showVideo,
              onDismiss: { print("Modal dismissed. State now: \(self.showVideo)")}
            ) {
              AVPlayerView(url: self.viewModel.location)
            }
          }
        }
        else if viewModel.isDownloading {
          Text("\(viewModel.progress)")
          if viewModel.progress >= 50 {
            Image(systemName: "circle.righthalf.fill")
          } else {
            Image(systemName: "circle")
          }
        }
        else {
          Button(action: { self.viewModel.download() }) {
            Image(systemName: "square.and.arrow.down")
          }
        }
      }
    }
  }
}
