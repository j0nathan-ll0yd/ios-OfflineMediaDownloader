import UIKit
import SwiftUI
import AuthenticationServices

struct RegistrationMessageView: View {
  let title = "Register"
  let message = "In order to download files to your specific device, Sign in with Apple."
  
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
    .frame(width: 280, alignment: .topLeading)
    .background(vividSkyBlue)
    .cornerRadius(6)
  }
}

#if DEBUG
struct RegistrationMessageView_Previews: PreviewProvider {
  static var previews: some View {
    RegistrationMessageView()
  }
}
#endif
