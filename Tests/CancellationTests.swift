import Foundation
import XCTest
@testable import ShipinKit

final class CancellationTests: XCTestCase {
  func testRunwayPreservesTransportCancellation() async throws {
    let client = RunwayML(
      apiKey: "test-secret",
      transport: CancellationTransport()
    )

    do {
      _ = try await client.task(id: "task-1")
      XCTFail("Expected cancellation")
    } catch {
      XCTAssertTrue(error is CancellationError)
    }
  }

  func testLumaPreservesTransportCancellation() async throws {
    let client = LumaAI(
      apiKey: "test-secret",
      transport: CancellationTransport()
    )

    do {
      _ = try await client.generation(id: "generation-1")
      XCTFail("Expected cancellation")
    } catch {
      XCTAssertTrue(error is CancellationError)
    }
  }
}

private struct CancellationTransport: ShipinTransport {
  func send(_ request: URLRequest) async throws -> ShipinHTTPResponse {
    throw CancellationError()
  }
}
