import Foundation
import SwiftUI


struct PendingFileView: View {
  var fileIds: [String]
  
  init(fileIds: [String]) {
    self.fileIds = fileIds
  }
  var body: some View {
    VStack(spacing: 0) {
      PendingFileMessageView().padding(20).background(Color(UIColor.secondarySystemBackground))
      List {
        Section(header: Text("Pending Downloads")) {
          ForEach(fileIds, id: \.self) { fileId in
            Text(fileId)
          }
        }
      }
    }
  }
}

#if DEBUG
struct PendingFileView_Previews: PreviewProvider {
  static var previews: some View {
    PendingFileView(fileIds: ["1234", "5678"])
  }
}
#endif
