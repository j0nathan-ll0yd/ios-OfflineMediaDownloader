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
            HStack() {
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

#if DEBUG

let file = File(key: "Short video", lastModified: Date(), eTag: "eTag", size: 3485113, storageClass: "STANDARD", fileUrl: URL(string: "http://example.com/video.mp4")!)
let file2 = File(key: "This is a video with a really long name to see how the sizing works for this text", lastModified: Date.init(timeInterval: -186400, since: Date()), eTag: "eTag", size: 3485113, storageClass: "STANDARD", fileUrl: URL(string: "https://kevin-and-bean-archive.s3.amazonaws.com/02%20Getting%20A%20Tattoo%20As%20A%20Payoff%20For%20A%20Bet-2018-02-02-Listener%20Call-in.mp3")!)

let viewModel = FileCellViewModel(file: file2, isDownloaded: true)

struct FileCellView_Previews : PreviewProvider {
    static var previews: some View {
        FileCellView(viewModel: viewModel)
    }
}
#endif

