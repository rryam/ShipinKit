import XCTest
@testable import ShipinKit

final class ShipinKitFacadeTests: XCTestCase {
  func testFacadeReturnsTypedRunwayResponse() async throws {
    let transport = RecordingTransport(responses: [fixture(#"{"id":"task-123"}"#)])
    let credential = ShipinCredential(apiKey: "test-secret")
    let client = ShipinClient(
      service: .runwayML(credential: credential),
      transport: transport
    )
    let source = try RunwayMLImageSource(url: URL(string: "https://example.com/input.jpg")!)
    let generation = try RunwayMLImageToVideoRequest(
      promptImage: source,
      promptText: "A cinematic wave rolling toward shore"
    )

    let response = try await client.generate(.runwayML(generation))

    XCTAssertEqual(response, .runwayML(RunwayMLCreateTaskResponse(id: "task-123")))
  }

  func testFacadeRejectsProviderMismatchWithoutNetwork() async throws {
    let transport = RecordingTransport(responses: [])
    let client = ShipinClient(
      service: .lumaAI(credential: ShipinCredential(apiKey: "test-secret")),
      transport: transport
    )
    let source = try RunwayMLImageSource(url: URL(string: "https://example.com/input.jpg")!)
    let generation = try RunwayMLImageToVideoRequest(
      promptImage: source,
      promptText: "A cinematic wave rolling toward shore"
    )

    do {
      _ = try await client.generate(.runwayML(generation))
      XCTFail("Expected a provider mismatch")
    } catch {
      XCTAssertEqual(
        error as? ShipinError,
        .providerMismatch(expected: .lumaAI, received: .runwayML)
      )
    }
    let requests = await transport.requests()
    XCTAssertTrue(requests.isEmpty)
  }
}
