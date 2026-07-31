import XCTest
@testable import ShipinKit

final class RunwayMLTests: XCTestCase {
  func testCreateUsesCurrentContractAndTypedResponse() async throws {
    let transport = RecordingTransport(responses: [fixture(#"{"id":"task-123"}"#)])
    let client = RunwayML(apiKey: "test-secret", transport: transport)
    let source = try RunwayMLImageSource(url: XCTUnwrap(URL(string: "https://example.com/input.jpg")))
    let generation = try RunwayMLImageToVideoRequest(
      model: .gen4Turbo,
      promptImage: source,
      promptText: "A slow camera push through morning fog",
      duration: .fiveSeconds,
      ratio: .landscape,
      seed: 42
    )

    let response = try await client.createImageToVideoTask(generation)

    XCTAssertEqual(response, RunwayMLCreateTaskResponse(id: "task-123"))
    let requests = await transport.requests()
    let request = try XCTUnwrap(requests.first)
    XCTAssertEqual(request.httpMethod, "POST")
    XCTAssertEqual(request.url?.path, "/v1/image_to_video")
    XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-secret")
    XCTAssertEqual(request.value(forHTTPHeaderField: "X-Runway-Version"), "2024-11-06")

    let body = try XCTUnwrap(request.httpBody)
    let object = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
    XCTAssertEqual(object["model"] as? String, "gen4_turbo")
    XCTAssertEqual(object["promptImage"] as? String, "https://example.com/input.jpg")
    XCTAssertEqual(object["ratio"] as? String, "1280:720")
    XCTAssertEqual(object["duration"] as? Int, 5)
    XCTAssertNil(object["watermark"])
  }

  func testTaskResponseDecodesEachStateShape() throws {
    let decoder = JSONDecoder()
    let running = try decoder.decode(
      RunwayMLTaskResponse.self,
      from: Data(#"{"id":"task-1","createdAt":"2026-07-31T08:12:00.123Z","status":"RUNNING","progress":0.5}"#.utf8)
    )
    XCTAssertEqual(running.state, .running(progress: 0.5))

    let cancelled = try decoder.decode(
      RunwayMLTaskResponse.self,
      from: Data(#"{"id":"task-2","createdAt":"2026-07-31T08:12:00Z","status":"CANCELLED"}"#.utf8)
    )
    XCTAssertEqual(cancelled.state, .cancelled)

    let failed = try decoder.decode(
      RunwayMLTaskResponse.self,
      from: Data(#"{"id":"task-3","createdAt":"2026-07-31T08:12:00Z","status":"FAILED","failure":"Input rejected","failureCode":"SAFETY.INPUT.TEXT"}"#.utf8)
    )
    XCTAssertEqual(failed.state, .failed(message: "Input rejected", code: "SAFETY.INPUT.TEXT"))
  }

  func testGeneratePollsFixtureResponsesWithoutLiveNetwork() async throws {
    let transport = RecordingTransport(responses: [
      fixture(#"{"id":"task-123"}"#),
      fixture(#"{"id":"task-123","createdAt":"2026-07-31T08:12:00Z","status":"RUNNING","progress":0.25}"#),
      fixture(#"{"id":"task-123","createdAt":"2026-07-31T08:12:00Z","status":"SUCCEEDED","output":["https://example.com/video.mp4"]}"#)
    ])
    let client = RunwayML(apiKey: "test-secret", transport: transport)
    let source = try RunwayMLImageSource(url: XCTUnwrap(URL(string: "https://example.com/input.jpg")))
    let generation = try RunwayMLImageToVideoRequest(
      promptImage: source,
      promptText: "A red kite rises into a clear sky"
    )

    let result = try await client.generateVideo(
      generation,
      pollInterval: .zero,
      timeout: .seconds(1)
    )

    XCTAssertEqual(result.output, [URL(string: "https://example.com/video.mp4")!])
    let requests = await transport.requests()
    XCTAssertEqual(requests.count, 3)
  }

  func testAPIErrorPreservesProviderMessageAndRetryability() async throws {
    let transport = RecordingTransport(responses: [
      fixture(#"{"error":"Too many requests"}"#, statusCode: 429)
    ])
    let client = RunwayML(apiKey: "test-secret", transport: transport)

    do {
      _ = try await client.task(id: "task-123")
      XCTFail("Expected an API error")
    } catch {
      XCTAssertEqual(
        error as? ShipinError,
        .api(
          provider: .runwayML,
          statusCode: 429,
          message: "Too many requests",
          retryable: true
        )
      )
    }
  }

  func testRequestValidationMatchesRunwayLimits() throws {
    XCTAssertThrowsError(try RunwayMLVideoDuration(seconds: 11))
    XCTAssertThrowsError(try RunwayMLImageSource(url: URL(string: "http://example.com/input.jpg")!))
    XCTAssertThrowsError(
      try RunwayMLImageSource(data: Data(), mimeType: "image/png;base64,invalid")
    )

    let source = try RunwayMLImageSource(url: URL(string: "https://example.com/input.jpg")!)
    XCTAssertThrowsError(
      try RunwayMLImageToVideoRequest(promptImage: source, promptText: "")
    )
  }

  func testTaskIdentifierCannotEscapeItsPathSegment() async throws {
    let transport = RecordingTransport(responses: [])
    let client = RunwayML(apiKey: "test-secret", transport: transport)

    do {
      _ = try await client.task(id: "../image_to_video")
      XCTFail("Expected identifier validation to fail")
    } catch let error as ShipinError {
      guard case .invalidRequest(field: "id", _) = error else {
        return XCTFail("Unexpected error: \(error)")
      }
    }
    let requests = await transport.requests()
    XCTAssertTrue(requests.isEmpty)
  }

  func testRequestUsesConfiguredTimeout() async throws {
    let transport = RecordingTransport(responses: [
      fixture(#"{"id":"task-1","createdAt":"2026-07-31T08:12:00Z","status":"PENDING"}"#)
    ])
    let client = RunwayML(
      apiKey: "test-secret",
      transport: transport,
      requestTimeout: 12
    )

    _ = try await client.task(id: "task-1")

    let requests = await transport.requests()
    let request = try XCTUnwrap(requests.first)
    XCTAssertEqual(request.timeoutInterval, 12)
    XCTAssertEqual(request.url?.path, "/v1/tasks/task-1")
  }

  func testInvalidPollingConfigurationFailsBeforeNetwork() async throws {
    let transport = RecordingTransport(responses: [])
    let client = RunwayML(apiKey: "test-secret", transport: transport)

    do {
      _ = try await client.waitForTask(id: "task-1", timeout: .zero)
      XCTFail("Expected timeout validation to fail")
    } catch let error as ShipinError {
      guard case .invalidRequest(field: "timeout", _) = error else {
        return XCTFail("Unexpected error: \(error)")
      }
    }
    let requests = await transport.requests()
    XCTAssertTrue(requests.isEmpty)
  }
}
