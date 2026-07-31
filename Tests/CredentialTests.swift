import XCTest
@testable import ShipinKit

final class CredentialTests: XCTestCase {
  func testDescriptionsAlwaysRedactAPIKey() {
    let secret = "sk-shipin-super-secret"
    let credential = ShipinCredential(apiKey: secret)

    XCTAssertEqual(String(describing: credential), "<redacted>")
    XCTAssertEqual(String(reflecting: credential), "<redacted>")
    let service = AIService.runwayML(credential: credential)
    XCTAssertFalse(String(describing: service).contains(secret))
    XCTAssertFalse(String(reflecting: service).contains(secret))
  }

  func testEmptyCredentialFailsBeforeTransport() async throws {
    let transport = RecordingTransport(responses: [])
    let client = RunwayML(apiKey: "  ", transport: transport)
    let source = try RunwayMLImageSource(url: XCTUnwrap(URL(string: "https://example.com/input.jpg")))
    let request = try RunwayMLImageToVideoRequest(
      promptImage: source,
      promptText: "A paper boat moving across a calm pond"
    )

    do {
      _ = try await client.createImageToVideoTask(request)
      XCTFail("Expected the missing credential error")
    } catch {
      XCTAssertEqual(error as? ShipinError, .missingCredential)
    }
    let requests = await transport.requests()
    XCTAssertTrue(requests.isEmpty)
  }

  func testCredentialProviderIsResolvedForEveryRequest() async throws {
    let values = CredentialValues(["first-key", "rotated-key"])
    let credential = ShipinCredential {
      try await values.next()
    }
    let transport = RecordingTransport(responses: [
      fixture(#"{"id":"task-1","createdAt":"2026-07-31T08:12:00Z","status":"PENDING"}"#),
      fixture(#"{"id":"task-1","createdAt":"2026-07-31T08:12:05Z","status":"PENDING"}"#)
    ])
    let client = RunwayML(credential: credential, transport: transport)

    _ = try await client.task(id: "task-1")
    _ = try await client.task(id: "task-1")

    let requests = await transport.requests()
    XCTAssertEqual(requests[0].value(forHTTPHeaderField: "Authorization"), "Bearer first-key")
    XCTAssertEqual(requests[1].value(forHTTPHeaderField: "Authorization"), "Bearer rotated-key")
  }
}

private actor CredentialValues {
  private var values: [String]

  init(_ values: [String]) {
    self.values = values
  }

  func next() throws -> String {
    guard !values.isEmpty else {
      throw ShipinError.missingCredential
    }
    return values.removeFirst()
  }
}
