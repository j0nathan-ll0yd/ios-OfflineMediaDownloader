import SwiftUI
import UIKit
import AVKit

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
  @State var player: AVPlayer
  
  init(viewModel: FileCellViewModel) {
    self.viewModel = viewModel
    self.player = AVPlayer()
  }
  
  var body: some View {
    ZStack {
      HStack {
        Image(systemName: "film")
        FileCellViewBody(file: self.viewModel.file)
        if viewModel.isDownloaded {
          Button(action: { self.showVideo.toggle() }) {
            Image(systemName: "play.circle").fullScreenCover(
              isPresented: $showVideo,
              onDismiss: { print("Modal dismissed. State now: \(self.showVideo)")}
            ) {
              VideoPlayer(player: self.player)
                .onAppear(perform: {
                  let asset: AVURLAsset = AVURLAsset(url: self.viewModel.location)
                  let playerItem = AVPlayerItem(asset: asset)
                  self.player = AVPlayer(playerItem:playerItem)
                  self.player.playImmediately(atRate: 1.0)
                })
                .onDisappear(perform: { player.pause() })
                .edgesIgnoringSafeArea(.all)
                .gesture(
                  DragGesture(minimumDistance: 20, coordinateSpace: .global)
                    .onEnded { value in
                        let horizontalAmount = value.translation.width
                        let verticalAmount = value.translation.height
                        if abs(horizontalAmount) > abs(verticalAmount) {
                          print(horizontalAmount < 0 ? "left swipe" : "right swipe")
                        } else {
                          print(verticalAmount < 0 ? "up swipe" : "down swipe")
                          if (verticalAmount > 0) {
                            self.showVideo = false
                          }
                        }
                    })
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
struct FileCellViewBody_Previews: PreviewProvider {
  static var previews: some View {
    return FileCellViewBody(file: TestHelper.getDefaultFile()!)
  }
}
#endif
