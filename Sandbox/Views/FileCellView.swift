import SwiftUI

struct FileCellView : View {
    @ObjectBinding var fileCellViewModel: FileCellViewModel
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: "film")
            VStack(alignment: .leading) {
                Text(self.fileCellViewModel.file.key)
                    .font(.body)
                    .lineLimit(nil)
                    .multilineTextAlignment(.leading)
                Text(self.fileCellViewModel.file.relativeDate)
                    .font(.subheadline)
                    .color(.gray)
            }
            Spacer()
            Text(self.fileCellViewModel.getProgress())
            Button(action: { self.fileCellViewModel.download() }) {
                Image(systemName: "square.and.arrow.down")
            }
        }
    }
}

#if DEBUG

let file = File(key: "Short video", lastModified: Date(), eTag: "eTag", size: 3485113, storageClass: "STANDARD", fileUrl: URL(string: "http://example.com/video.mp4")!)

struct FileCellView_Previews : PreviewProvider {
    static var previews: some View {
        FileCellView(fileCellViewModel: FileCellViewModel(file: file))
    }
}
#endif

