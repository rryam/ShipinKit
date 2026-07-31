import XCTest
@testable import ShipinKit

final class LumaAITests: XCTestCase {
  func testCreateUsesCurrentVideoEndpointAndTypedGeneration() async throws {
    let response = #"{"id":"generation-1","state":"dreaming","failure_reason":null,"created_at":"2026-07-31T08:12:00Z","assets":{},"generation_type":"video","model":"ray-2","request":{"generation_type":"video","prompt":"A tiger walking in snow","model":"ray-2"}}"#
    let transport = RecordingTransport(responses: [fixture(response, statusCode: 201)])
    let client = LumaAI(apiKey: "luma-test-secret", transport: transport)
    let generation = try LumaAIGenerationRequest(
      prompt: "A tiger walking in snow",
      model: .ray2,
      resolution: .p720,
      duration: .fiveSeconds,
      aspectRatio: .landscape
    )

    let created = try await client.createGeneration(generation)

    XCTAssertEqual(created.id, "generation-1")
    XCTAssertEqual(created.state, .dreaming)
    let requests = await transport.requests()
    let request = try XCTUnwrap(requests.first)
    XCTAssertEqual(request.url?.path, "/dream-machine/v1/generations/video")
    XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer luma-test-secret")

    let body = try XCTUnwrap(request.httpBody)
    let object = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
    XCTAssertEqual(object["model"] as? String, "ray-2")
    XCTAssertEqual(object["resolution"] as? String, "720p")
    XCTAssertEqual(object["duration"] as? String, "5s")
    XCTAssertEqual(object["generation_type"] as? String, "video")
  }

  func testListDecodesPaginationEnvelope() async throws {
    let response = #"{"has_more":false,"count":1,"limit":100,"offset":0,"generations":[{"id":"generation-1","state":"completed","failure_reason":null,"created_at":"2026-07-31T08:12:00Z","assets":{"image":"https://example.com/poster.jpg","progress_video":"https://example.com/progress.mp4","video":"https://example.com/luma.mp4"},"generation_type":"video","model":"ray-2"}]}"#
    let transport = RecordingTransport(responses: [fixture(response)])
    let client = LumaAI(apiKey: "luma-test-secret", transport: transport)

    let page = try await client.listGenerations()

    XCTAssertEqual(page.count, 1)
    XCTAssertEqual(page.generations.first?.assets?.video, URL(string: "https://example.com/luma.mp4"))
    XCTAssertEqual(page.generations.first?.assets?.progressVideo, URL(string: "https://example.com/progress.mp4"))
    XCTAssertEqual(page.generations.first?.model, "ray-2")
    let requests = await transport.requests()
    let request = try XCTUnwrap(requests.first)
    let components = try XCTUnwrap(URLComponents(url: XCTUnwrap(request.url), resolvingAgainstBaseURL: false))
    XCTAssertEqual(components.queryItems, [
      URLQueryItem(name: "limit", value: "100"),
      URLQueryItem(name: "offset", value: "0")
    ])
  }

  func testUnknownGenerationStateIsPreserved() throws {
    let response = #"{"id":"generation-1","state":"moderating","created_at":"2026-07-31T08:12:00Z"}"#
    let generation = try JSONDecoder().decode(LumaAIGeneration.self, from: Data(response.utf8))
    XCTAssertEqual(generation.state, .unknown("moderating"))
  }

  func testFutureResolutionAndDurationValuesArePreserved() throws {
    let request = try LumaAIGenerationRequest(
      prompt: "A tiger walking in snow",
      resolution: .custom("2160p"),
      duration: .custom("12s")
    )

    let object = try XCTUnwrap(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(request)) as? [String: Any]
    )
    XCTAssertEqual(object["resolution"] as? String, "2160p")
    XCTAssertEqual(object["duration"] as? String, "12s")
  }

  func testListConceptsUsesCurrentEndpoint() async throws {
    let transport = RecordingTransport(responses: [fixture(#"["dolly_zoom","handheld"]"#)])
    let client = LumaAI(apiKey: "luma-test-secret", transport: transport)

    let concepts = try await client.listConcepts()

    XCTAssertEqual(concepts, ["dolly_zoom", "handheld"])
    let requests = await transport.requests()
    XCTAssertEqual(requests.first?.url?.path, "/dream-machine/v1/generations/concepts/list")
  }

  func testLoopValidationRejectsTwoKeyframes() throws {
    let keyframes = try LumaAIKeyframes(
      frame0: .image(URL(string: "https://example.com/start.jpg")!),
      frame1: .image(URL(string: "https://example.com/end.jpg")!)
    )
    XCTAssertThrowsError(
      try LumaAIGenerationRequest(
        prompt: "A controlled transition between frames",
        loop: true,
        keyframes: keyframes
      )
    )
  }

  func testGeneratePollsFixturesAndReturnsTypedVideo() async throws {
    let transport = RecordingTransport(responses: [
      fixture(#"{"id":"generation-1","state":"dreaming","created_at":"2026-07-31T08:12:00Z"}"#, statusCode: 201),
      fixture(#"{"id":"generation-1","state":"dreaming","created_at":"2026-07-31T08:12:01Z"}"#),
      fixture(#"{"id":"generation-1","state":"completed","created_at":"2026-07-31T08:12:02Z","assets":{"video":"https://example.com/video.mp4"}}"#)
    ])
    let client = LumaAI(apiKey: "luma-test-secret", transport: transport)
    let request = try LumaAIGenerationRequest(prompt: "A tiger walking in snow")

    let result = try await client.generateVideo(
      request,
      pollInterval: .zero,
      timeout: .seconds(1)
    )

    XCTAssertEqual(result.videoURL, URL(string: "https://example.com/video.mp4"))
    let requests = await transport.requests()
    XCTAssertEqual(requests.count, 3)
  }

  func testValidationErrorMessageDecodesLumaDetailEnvelope() async throws {
    let transport = RecordingTransport(responses: [
      fixture(#"{"detail":[{"loc":["body","prompt"],"msg":"Prompt is required","type":"missing"}]}"#, statusCode: 422)
    ])
    let client = LumaAI(apiKey: "luma-test-secret", transport: transport)
    let request = try LumaAIGenerationRequest(prompt: "A tiger walking in snow")

    do {
      _ = try await client.createGeneration(request)
      XCTFail("Expected an API error")
    } catch {
      XCTAssertEqual(
        error as? ShipinError,
        .api(
          provider: .lumaAI,
          statusCode: 422,
          message: "Prompt is required",
          retryable: false
        )
      )
    }
  }

  func testGenerationIdentifierCannotEscapeItsPathSegment() async throws {
    let transport = RecordingTransport(responses: [])
    let client = LumaAI(apiKey: "luma-test-secret", transport: transport)

    do {
      _ = try await client.generation(id: "generation%2Fvideo")
      XCTFail("Expected identifier validation to fail")
    } catch let error as ShipinError {
      guard case .invalidRequest(field: "id", _) = error else {
        return XCTFail("Unexpected error: \(error)")
      }
    }
    let requests = await transport.requests()
    XCTAssertTrue(requests.isEmpty)
  }

  func testGenerateFailsTruthfullyWhenCreateResponseHasNoIdentifier() async throws {
    let transport = RecordingTransport(responses: [
      fixture(#"{"state":"queued"}"#, statusCode: 201)
    ])
    let client = LumaAI(apiKey: "luma-test-secret", transport: transport)
    let request = try LumaAIGenerationRequest(prompt: "A tiger walking in snow")

    do {
      _ = try await client.generateVideo(request)
      XCTFail("Expected a missing field error")
    } catch {
      XCTAssertEqual(
        error as? ShipinError,
        .missingResponseField(provider: .lumaAI, field: "id")
      )
    }
  }
}
