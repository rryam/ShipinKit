import Foundation

#if canImport(UIKit)
import UIKit
#endif

#if canImport(AppKit)
import AppKit
#endif

/// A typed client for Runway's public REST API.
public actor RunwayML {
  /// The current API version required by Runway.
  public static let apiVersion = "2024-11-06"

  private let credential: ShipinCredential
  private let transport: any ShipinTransport
  private let baseURL: URL
  private let requestTimeout: TimeInterval

  public init(
    credential: ShipinCredential,
    transport: any ShipinTransport = URLSessionShipinTransport(),
    baseURL: URL = URL(string: "https://api.dev.runwayml.com/v1")!,
    requestTimeout: TimeInterval = 60
  ) {
    self.credential = credential
    self.transport = transport
    self.baseURL = baseURL
    self.requestTimeout = requestTimeout
  }

  /// Convenience initializer for an API key already loaded by the application.
  public init(
    apiKey: String,
    transport: any ShipinTransport = URLSessionShipinTransport(),
    baseURL: URL = URL(string: "https://api.dev.runwayml.com/v1")!,
    requestTimeout: TimeInterval = 60
  ) {
    self.init(
      credential: ShipinCredential(apiKey: apiKey),
      transport: transport,
      baseURL: baseURL,
      requestTimeout: requestTimeout
    )
  }

  /// Starts an image-to-video task without polling it.
  public func createImageToVideoTask(
    _ generation: RunwayMLImageToVideoRequest
  ) async throws -> RunwayMLCreateTaskResponse {
    var request = try await request(path: "image_to_video", method: "POST")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try JSONEncoder().encode(generation)
    let response = try await send(request)
    return try decode(RunwayMLCreateTaskResponse.self, from: response.data)
  }

  /// Gets the latest typed state for a task.
  public func task(id: String) async throws -> RunwayMLTaskResponse {
    try await task(id: id, timeoutInterval: nil)
  }

  private func task(
    id: String,
    timeoutInterval: TimeInterval?
  ) async throws -> RunwayMLTaskResponse {
    try validatePathIdentifier(id, field: "id")
    let request = try await request(
      pathComponents: ["tasks", id],
      method: "GET",
      timeoutInterval: timeoutInterval
    )
    let response = try await send(request)
    return try decode(RunwayMLTaskResponse.self, from: response.data)
  }

  /// Cancels an active task or deletes a terminal task.
  public func cancelOrDeleteTask(id: String) async throws {
    try validatePathIdentifier(id, field: "id")
    let request = try await request(pathComponents: ["tasks", id], method: "DELETE")
    _ = try await send(request)
  }

  /// Starts a task and waits for its output using Runway's five-second polling guidance.
  public func generateVideo(
    _ generation: RunwayMLImageToVideoRequest,
    pollInterval: Duration = .seconds(5),
    timeout: Duration = .seconds(600)
  ) async throws -> RunwayMLGeneratedVideo {
    let created = try await createImageToVideoTask(generation)
    return try await waitForTask(
      id: created.id,
      pollInterval: pollInterval,
      timeout: timeout
    )
  }

  /// Waits for an existing task and returns a complete, typed generation receipt.
  public func waitForTask(
    id: String,
    pollInterval: Duration = .seconds(5),
    timeout: Duration = .seconds(600)
  ) async throws -> RunwayMLGeneratedVideo {
    try validatePolling(pollInterval: pollInterval, timeout: timeout)
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: timeout)

    while true {
      try Task.checkCancellation()
      let now = clock.now
      guard now < deadline else {
        throw ShipinError.generationTimedOut(provider: .runwayML)
      }
      let remaining = now.duration(to: deadline)
      let response = try await task(
        id: id,
        timeoutInterval: min(requestTimeout, remaining.timeInterval)
      )
      guard clock.now <= deadline else {
        throw ShipinError.generationTimedOut(provider: .runwayML)
      }
      switch response.state {
        case .succeeded(let output):
          guard !output.isEmpty else {
            throw ShipinError.missingOutput(provider: .runwayML)
          }
          return RunwayMLGeneratedVideo(task: response, output: output)
        case .failed(let message, let code):
          throw ShipinError.generationFailed(
            provider: .runwayML,
            code: code,
            message: message ?? "The provider did not include a failure reason."
          )
        case .cancelled:
          throw ShipinError.generationCancelled(provider: .runwayML)
        case .pending, .throttled, .running:
          let now = clock.now
          guard now < deadline else {
            throw ShipinError.generationTimedOut(provider: .runwayML)
          }
          let remaining = now.duration(to: deadline)
          try await Task.sleep(for: min(pollInterval, remaining))
      }
    }
  }

  /// Converts a platform image into a validated JPEG data-URI source.
  public nonisolated static func imageSource(from image: ShipinImage) throws -> RunwayMLImageSource {
    let data: Data
#if os(macOS)
    guard
      let tiffRepresentation = image.tiffRepresentation,
      let bitmapImage = NSBitmapImageRep(data: tiffRepresentation),
      let jpegData = bitmapImage.representation(using: .jpeg, properties: [:])
    else {
      throw ShipinError.invalidRequest(
        field: "promptImage",
        reason: "The NSImage could not be converted to JPEG."
      )
    }
    data = jpegData
#else
    guard let jpegData = image.jpegData(compressionQuality: 1) else {
      throw ShipinError.invalidRequest(
        field: "promptImage",
        reason: "The UIImage could not be converted to JPEG."
      )
    }
    data = jpegData
#endif
    return try RunwayMLImageSource(data: data, mimeType: "image/jpeg")
  }

  private func request(path: String, method: String) async throws -> URLRequest {
    try await request(pathComponents: [path], method: method, timeoutInterval: nil)
  }

  private func request(
    pathComponents: [String],
    method: String,
    timeoutInterval: TimeInterval? = nil
  ) async throws -> URLRequest {
    let timeoutInterval = timeoutInterval ?? requestTimeout
    guard timeoutInterval > 0 else {
      throw ShipinError.invalidRequest(
        field: "requestTimeout",
        reason: "The request timeout must be greater than zero."
      )
    }
    let url = pathComponents.reduce(baseURL) { url, component in
      url.appendingPathComponent(component)
    }
    var request = URLRequest(url: url, timeoutInterval: timeoutInterval)
    request.httpMethod = method
    request.setValue(
      try await credential.authorizationHeaderValue(),
      forHTTPHeaderField: "Authorization"
    )
    request.setValue(Self.apiVersion, forHTTPHeaderField: "X-Runway-Version")
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    return request
  }

  private func send(_ request: URLRequest) async throws -> ShipinHTTPResponse {
    let response: ShipinHTTPResponse
    do {
      response = try await transport.send(request)
    } catch let error as ShipinError {
      throw error
    } catch {
      throw ShipinError.transportFailure(String(describing: error))
    }

    guard (200...299).contains(response.statusCode) else {
      throw ShipinError.api(
        provider: .runwayML,
        statusCode: response.statusCode,
        message: decodeAPIErrorMessage(from: response.data),
        retryable: [429, 502, 503, 504].contains(response.statusCode)
      )
    }
    return response
  }

  private func decode<Value: Decodable>(
    _ type: Value.Type,
    from data: Data
  ) throws -> Value {
    do {
      return try JSONDecoder().decode(type, from: data)
    } catch {
      throw ShipinError.responseDecodingFailed(
        provider: .runwayML,
        reason: String(describing: error)
      )
    }
  }

  private func validatePolling(pollInterval: Duration, timeout: Duration) throws {
    guard pollInterval >= .zero else {
      throw ShipinError.invalidRequest(
        field: "pollInterval",
        reason: "The polling interval cannot be negative."
      )
    }
    guard timeout > .zero else {
      throw ShipinError.invalidRequest(
        field: "timeout",
        reason: "The polling timeout must be greater than zero."
      )
    }
  }
}

private extension Duration {
  var timeInterval: TimeInterval {
    let components = self.components
    return TimeInterval(components.seconds)
      + TimeInterval(components.attoseconds) / 1_000_000_000_000_000_000
  }
}
