import SwiftUI

struct LoginStatusView: View {
  let title = "Login Status"
  var message: String
  @State var status: LoginStatus
  init(status: LoginStatus) {
    self.status = status
    switch status {
    case .unauthenticated:
      self.message = "Unauthenticated"
    case .authenticated:
      self.message = "Authenticated"
    }
  }
  
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
    .background(shinyShamrock)
    .cornerRadius(6)
  }
}

#if DEBUG
struct LoginStatusView_Previews: PreviewProvider {
  static var previews: some View {
    LoginStatusView(status: .unauthenticated)
  }
}
#endif
