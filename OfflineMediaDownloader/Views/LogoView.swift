import UIKit
import SwiftUI
import AuthenticationServices

struct LogoView: View {
  var body: some View {
    Image(systemName: "puzzlepiece")
        .resizable()
        .scaledToFit()
        .frame(width: 100.0, height: 100.0)
        .padding(10.0)
        .background(Color.white)
        .clipShape(Circle())
        .shadow(radius: 5.0)
    Text("Lifegames").font(.title)
    Text("OfflineMediaDownloader").font(.title2)
  }
}

#if DEBUG
struct LogoView_Previews: PreviewProvider {
  static var previews: some View {
    LogoView()
  }
}
#endif
