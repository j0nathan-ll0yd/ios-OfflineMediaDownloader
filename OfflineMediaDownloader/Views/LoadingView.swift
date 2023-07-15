import Foundation
import SwiftUI

struct LoadingView<Content>: View where Content: View {
  @Binding var isShowing: Bool
  var content: () -> Content

  var body: some View {
    GeometryReader { geometry in
      ZStack(alignment: .center) {
        self.content()
            .disabled(self.isShowing)
            .blur(radius: self.isShowing ? 3 : 0)

        VStack {
            ProgressView().tint(.black)
        }
        .opacity(self.isShowing ? 1 : 0)
      }
    }.edgesIgnoringSafeArea(.top)
  }
}
