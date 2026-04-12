import Foundation

struct DeleteFileResponseDetail: Codable, Sendable {
    var deleted: Bool
    var fileRemoved: Bool
}

struct DeleteFileResponse: Codable, Sendable {
    var body: DeleteFileResponseDetail?
    var error: ErrorDetail?
    var requestId: String
}
