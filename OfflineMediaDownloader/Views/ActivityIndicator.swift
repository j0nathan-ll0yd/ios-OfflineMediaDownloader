import SwiftUI

// https://jetrockets.pro/blog/activity-indicator-in-swiftui
struct ActivityIndicator: View {
  @State private var isAnimating: Bool = false

  var body: some View {
    Text("ActivityIndicator")
  }
}

#if DEBUG
struct ActivityIndicator_Previews: PreviewProvider {
  static var previews: some View {
    ActivityIndicator()
  }
}
#endif
