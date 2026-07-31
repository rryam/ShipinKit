import Foundation
@testable import ShipinKit

enum RecordingTransportError: Error {
  case missingResponse
}

actor RecordingTransport: ShipinTransport {
  private var queuedResponses: [ShipinHTTPResponse]
  private var recordedRequests: [URLRequest] = []

  init(responses: [ShipinHTTPResponse]) {
    self.queuedResponses = responses
  }

  func send(_ request: URLRequest) async throws -> ShipinHTTPResponse {
    recordedRequests.append(request)
    guard !queuedResponses.isEmpty else {
      throw RecordingTransportError.missingResponse
    }
    return queuedResponses.removeFirst()
  }

  func requests() -> [URLRequest] {
    recordedRequests
  }
}

func fixture(_ json: String, statusCode: Int = 200) -> ShipinHTTPResponse {
  ShipinHTTPResponse(data: Data(json.utf8), statusCode: statusCode)
}
