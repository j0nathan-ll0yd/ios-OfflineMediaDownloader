//
//  RegisterDeviceResponse.swift
//  OfflineMediaDownloader
//
//  Created by Jonathan Lloyd on 2/13/21.
//  Copyright © 2021 Jonathan Lloyd. All rights reserved.
//

import Foundation

struct EndpointResponse: Codable, Sendable {
  var endpointArn: String
}

public struct RegisterDeviceResponse: Codable, Sendable {
  var body: EndpointResponse
  var error: ErrorDetail?
  var requestId: String
}
