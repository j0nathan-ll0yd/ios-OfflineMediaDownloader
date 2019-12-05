import SwiftUI

struct FileResponse : Decodable {
    var body: FileList
    var requestId: String
}
