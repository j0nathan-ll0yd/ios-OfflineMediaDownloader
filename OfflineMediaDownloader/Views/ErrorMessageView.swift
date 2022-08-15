import UIKit
import SwiftUI
import AuthenticationServices

struct ErrorMessageView: View {
  let title = "Oops! Login Required"
  let message = "It looks like you need to login."
  
  var body: some View {
    // You've been logged out
    VStack(alignment: .leading) {
        Label(title, systemImage: "exclamationmark.circle")
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
    .frame(width: 280, alignment: .topLeading)
    .background(rustyRed)
    .cornerRadius(6)
  }
}

#if DEBUG
struct ErrorMessageView_Previews: PreviewProvider {
  static var previews: some View {
    ErrorMessageView()
  }
}
#endif
