
import PlaygroundSupport
import SwiftUI
import AuthenticationServices

final class SignInWithApple: UIViewRepresentable {
  func makeUIView(context: Context) -> ASAuthorizationAppleIDButton {
    return ASAuthorizationAppleIDButton()
  }
  func updateUIView(_ uiView: ASAuthorizationAppleIDButton, context: Context) {
  }
}

let red = Color(red: 240 / 255, green: 58 / 255, blue: 71 / 255)
let rustyRed = Color(red: 218 / 255, green: 53 / 255, blue: 65 / 255)
let yellow = Color(red: 254/255, green: 227/255, blue: 73/255)
let logo = Image(uiImage: UIImage(named: "lifegames-logo.jpg")!)
let shinyShamrock = Color(red: 104 / 255, green: 182 / 255, blue: 132 / 255)
let vividSkyBlue = Color(red: 102 / 255, green: 199 / 255, blue: 244 / 255)

struct Tag: Identifiable {
    var id: String { name }
    var name: String
}

struct ContentView: View {
    let tags = [
        Tag(name: "UserData"),
        Tag(name: "Token"),
        Tag(name: "DeviceData")
    ]
    var body: some View {
        List {
            Section(header: Text("Keychain Storage")) {
                ForEach(0 ..< tags.count) { value in
                    Text("Hello")
                }.onDelete { indexSet in
                    print("Deleted")
                }
            }
        }.listStyle(GroupedListStyle())
    }
}

struct LoginView: View {
    var body: some View {
        ZStack {
          yellow.edgesIgnoringSafeArea(.all)
          VStack {
            // You need to register to proceed
            VStack(alignment: .leading) {
                Label("Register", systemImage: "person").font(.headline).padding(.horizontal, 5.0).padding(.top, 5.0).foregroundColor(Color.white)
                Text("To order to download files to your specific device, Sign in with Apple.").font(.caption).padding(.horizontal, 10.0).padding(.vertical, 3.0).padding(.bottom, 5.0).foregroundColor(Color.black)
            }
            .frame(width: 280, alignment: .topLeading)
            .background(vividSkyBlue)
            .cornerRadius(6)
            
            // You've been logged out
            VStack(alignment: .leading) {
                Label("Oops! Login Required", systemImage: "exclamationmark.circle").font(.headline).padding(.horizontal, 5.0).padding(.top, 5.0).foregroundColor(Color.white)
                Text("To order to download files to your specific device, Sign in with Apple.").font(.caption).padding(.horizontal, 10.0).padding(.vertical, 3.0).padding(.bottom, 5.0).foregroundColor(Color.black)
            }
            .frame(width: 280, alignment: .topLeading)
            .background(rustyRed)
            .cornerRadius(6)
            
            Spacer().frame(height: 50)
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
            SignInWithApple().frame(width: 280, height: 60)
            VStack {
                Button(action: { print("button pressed") }) {
                  Text("No thanks")
                }
            }
            .frame(width: 280, alignment: .center)
          }
        }
    }
}

PlaygroundPage.current.setLiveView(ContentView().frame(width: 418, height: 896))
