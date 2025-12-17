//
//  ErrorMessageView.swift
//  OfflineMediaDownloader
//
//  Created by Jonathan Lloyd on 10/24/24.
//


import SwiftUI

struct ErrorMessageView: View {
  let title = "Oops! Our bad :("
  var message: String
  init(message: String) {
    self.message = message
  }
  
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
    ErrorMessageView(message: "A bad thing happened.")
  }
}
#endif
