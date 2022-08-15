//
//  RegisterDeviceResponse.swift
//  OfflineMediaDownloader
//
//  Created by Jonathan Lloyd on 2/13/21.
//  Copyright © 2021 Jonathan Lloyd. All rights reserved.
//

import Foundation

struct EndpointResponse: Decodable {
  var endpointArn: String
}

struct RegisterDeviceResponse: Decodable {
  var body: EndpointResponse
  var requestId: String
}
