import SwiftUI

struct RegistrationStatusView: View {
  let title = "Registration Status"
  var message: String
  @State var status: RegistrationStatus
  init(status: RegistrationStatus) {
    self.status = status
    switch status {
    case .registered:
      self.message = "Registered"
    case .unregistered:
      self.message = "Unregistered"
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
    .background(vividSkyBlue)
    .cornerRadius(6)
  }
}

#if DEBUG
struct RegistrationMessageView_Previews: PreviewProvider {
  static var previews: some View {
    RegistrationStatusView(status: .unregistered)
  }
}
#endif
