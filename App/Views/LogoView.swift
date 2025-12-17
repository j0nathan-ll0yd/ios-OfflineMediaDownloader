//
//  LogoView.swift
//  OfflineMediaDownloader
//
//  Created by Jonathan Lloyd on 10/21/24.
//


import SwiftUI

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
