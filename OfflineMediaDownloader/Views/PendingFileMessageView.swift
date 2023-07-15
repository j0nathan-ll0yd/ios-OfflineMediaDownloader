import UIKit
import SwiftUI
import AuthenticationServices

struct PendingFileMessageView: View {
  let title = "Pending Downloads"
  let message = "These are the files pending download. First, they are stored on the server and then downloadable to your device. Once the download completes, it will be removed from this list. If a download has been pending for a while, report it."
  
  var body: some View {
    // You need to register to proceed
    VStack(alignment: .leading) {
        Label(title, systemImage: "person")
          .font(.headline)
          .padding(.horizontal, 5.0)
          .padding(.top, 5.0)
          .foregroundColor(Color.white)
        Text(message)
          .font(.caption)
          .padding(.horizontal, 10.0)
          .padding(.vertical, 3.0)
          .padding(.bottom, 5.0)
          .foregroundColor(Color.black)
    }
    .frame(maxWidth: .infinity, alignment: .topLeading)
    .background(vividSkyBlue)
    .cornerRadius(6)
  }
}

#if DEBUG
struct PendingFileMessageView_Previews: PreviewProvider {
  static var previews: some View {
    PendingFileMessageView()
  }
}
#endif
