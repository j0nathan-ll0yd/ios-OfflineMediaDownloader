import SwiftUI

import SwiftUI

struct DownloadFileResponseDetail: Decodable {
  var status: String
}


struct DownloadFileResponse: Decodable {
  var body: DownloadFileResponseDetail
  var requestId: String
}
