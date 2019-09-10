import SwiftUI

struct FileCellView : View {
    @ObservedObject var viewModel: FileCellViewModel
    
    init(viewModel: FileCellViewModel) {
      self.viewModel = viewModel
    }
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: "film")
            VStack(alignment: .leading) {
                Text("\(viewModel.file.key)")
                    .font(.body)
                    .lineLimit(nil)
                    .multilineTextAlignment(.leading)
                Text("\(viewModel.file.relativeDate)")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            Spacer()
            Text("\(viewModel.progress)")
            Button(action: { self.viewModel.download() }) {
                Image(systemName: "square.and.arrow.down")
            }
        }
    }
}

#if DEBUG

let file = File(key: "Short video", lastModified: Date(), eTag: "eTag", size: 3485113, storageClass: "STANDARD", fileUrl: URL(string: "http://example.com/video.mp4")!)
let file2 = File(key: "This is a video with a really long name to see how the sizing works for this text", lastModified: Date.init(timeInterval: -186400, since: Date()), eTag: "eTag", size: 3485113, storageClass: "STANDARD", fileUrl: URL(string: "https://kevin-and-bean-archive.s3.amazonaws.com/02%20Getting%20A%20Tattoo%20As%20A%20Payoff%20For%20A%20Bet-2018-02-02-Listener%20Call-in.mp3")!)

struct FileCellView_Previews : PreviewProvider {
    static var previews: some View {
        FileCellView(viewModel: FileCellViewModel(file: file2))
    }
}
#endif

