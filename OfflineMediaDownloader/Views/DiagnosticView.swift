import Foundation
import SwiftUI

struct DetailView: View {
  var tappedItem: KeychainData
  
  init(tappedItem: KeychainData) {
    self.tappedItem = tappedItem
  }
  
  var body: some View {
    List {
      if (tappedItem.data is Token) {
        let token = tappedItem.data as! Token
        Section(header: Text("Token")) {
          Text(token.decoded)
        }
      }
      if (tappedItem.data is UserData) {
        let userData = tappedItem.data as! UserData
        Section(header: Text("Email")) {
          Text(userData.email)
        }
        Section(header: Text("First Name")) {
          Text(userData.firstName)
        }
        Section(header: Text("Last Name")) {
          Text(userData.lastName)
        }
        Section(header: Text("Identifier")) {
          Text(userData.identifier)
        }
      }
      if (tappedItem.data is DeviceData) {
        let deviceData = tappedItem.data as! DeviceData
        Section(header: Text("Endpoint ARN")) {
          Text(deviceData.endpointArn)
        }
      }
    }
  }
}

struct DiagnosticView: View {
  @State var itemTapped: KeychainData?
  @ObservedObject var viewModel: DiagnosticViewModel = DiagnosticViewModel()
  var body: some View {
    NavigationView {
      List {
        Section(header: Text("Keychain Storage")) {
          ForEach(viewModel.keychainObjects) { object in
            NavigationLink(destination: DetailView(tappedItem: object)) {
              Text(object.name)
            }
          }.onDelete { indexSet in
            viewModel.handleDelete(at: indexSet)
          }
        }
        Section(header: Text("Debug Actions")) {
          Button(action: { viewModel.purgeAllLocalFiles() }) {
            Label("Truncate Files", systemImage: "video")
          }
        }
      }
      .listStyle(GroupedListStyle())
    }.navigationBarHidden(true)
  }
}

#if DEBUG
struct DiagnosticView_Previews: PreviewProvider {
  static var previews: some View {
    DiagnosticView()
  }
}
#endif
