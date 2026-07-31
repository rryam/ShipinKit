import Foundation

/// A typed client for Luma's Dream Machine video API.
public actor LumaAI {
  private let credential: ShipinCredential
  private let transport: any ShipinTransport
  private let baseURL: URL
  private let requestTimeout: TimeInterval

  public init(
    credential: ShipinCredential,
    transport: any ShipinTransport = URLSessionShipinTransport(),
    baseURL: URL = URL(string: "https://api.lumalabs.ai")!,
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
    baseURL: URL = URL(string: "https://api.lumalabs.ai")!,
    requestTimeout: TimeInterval = 60
  ) {
    self.init(
      credential: ShipinCredential(apiKey: apiKey),
      transport: transport,
      baseURL: baseURL,
      requestTimeout: requestTimeout
    )
  }

  /// Starts a video generation using Luma's current `/generations/video` contract.
  public func createGeneration(
    _ generation: LumaAIGenerationRequest
  ) async throws -> LumaAIGeneration {
    var request = try await request(
      path: "dream-machine/v1/generations/video",
      method: "POST"
    )
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try JSONEncoder().encode(generation)
    let response = try await send(request)
    return try decode(LumaAIGeneration.self, from: response.data)
  }

  /// Retrieves one generation by ID.
  public func generation(id: String) async throws -> LumaAIGeneration {
    try await generation(id: id, timeoutInterval: nil)
  }

  private func generation(
    id: String,
    timeoutInterval: TimeInterval?
  ) async throws -> LumaAIGeneration {
    try validatePathIdentifier(id, field: "id")
    let request = try await request(
      pathComponents: ["dream-machine", "v1", "generations", id],
      method: "GET",
      timeoutInterval: timeoutInterval
    )
    let response = try await send(request)
    return try decode(LumaAIGeneration.self, from: response.data)
  }

  /// Lists generations using Luma's pagination envelope.
  public func listGenerations(limit: Int = 100, offset: Int = 0) async throws -> LumaAIGenerationList {
    guard limit > 0 else {
      throw ShipinError.invalidRequest(field: "limit", reason: "Limit must be greater than zero.")
    }
    guard offset >= 0 else {
      throw ShipinError.invalidRequest(field: "offset", reason: "Offset cannot be negative.")
    }

    var components = URLComponents(
      url: baseURL.appendingPathComponent("dream-machine/v1/generations"),
      resolvingAgainstBaseURL: false
    )
    components?.queryItems = [
      URLQueryItem(name: "limit", value: String(limit)),
      URLQueryItem(name: "offset", value: String(offset))
    ]
    guard let url = components?.url else {
      throw ShipinError.invalidRequest(field: "pagination", reason: "Could not construct the URL.")
    }

    let request = try await request(url: url, method: "GET")
    let response = try await send(request)
    return try decode(LumaAIGenerationList.self, from: response.data)
  }

  /// Deletes a generation and its retained provider assets.
  public func deleteGeneration(id: String) async throws {
    try validatePathIdentifier(id, field: "id")
    let request = try await request(
      pathComponents: ["dream-machine", "v1", "generations", id],
      method: "DELETE"
    )
    _ = try await send(request)
  }

  /// Retrieves Luma's supported generation concepts.
  public func listConcepts() async throws -> [String] {
    let request = try await request(
      path: "dream-machine/v1/generations/concepts/list",
      method: "GET"
    )
    let response = try await send(request)
    return try decode([String].self, from: response.data)
  }

  /// Starts a generation and waits for a terminal state.
  public func generateVideo(
    _ generation: LumaAIGenerationRequest,
    pollInterval: Duration = .seconds(5),
    timeout: Duration = .seconds(600)
  ) async throws -> LumaAIGeneratedVideo {
    let created = try await createGeneration(generation)
    guard let id = created.id else {
      throw ShipinError.missingResponseField(provider: .lumaAI, field: "id")
    }
    return try await waitForGeneration(
      id: id,
      pollInterval: pollInterval,
      timeout: timeout
    )
  }

  /// Waits for an existing Luma generation and returns its complete typed receipt.
  public func waitForGeneration(
    id: String,
    pollInterval: Duration = .seconds(5),
    timeout: Duration = .seconds(600)
  ) async throws -> LumaAIGeneratedVideo {
    try validatePolling(pollInterval: pollInterval, timeout: timeout)
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: timeout)

    while true {
      try Task.checkCancellation()
      let now = clock.now
      guard now < deadline else {
        throw ShipinError.generationTimedOut(provider: .lumaAI)
      }
      let remaining = now.duration(to: deadline)
      let response = try await generation(
        id: id,
        timeoutInterval: min(requestTimeout, remaining.timeInterval)
      )
      guard clock.now <= deadline else {
        throw ShipinError.generationTimedOut(provider: .lumaAI)
      }
      guard let state = response.state else {
        throw ShipinError.missingResponseField(provider: .lumaAI, field: "state")
      }
      switch state {
        case .completed:
          guard let videoURL = response.assets?.video else {
            throw ShipinError.missingOutput(provider: .lumaAI)
          }
          return LumaAIGeneratedVideo(generation: response, videoURL: videoURL)
        case .failed:
          throw ShipinError.generationFailed(
            provider: .lumaAI,
            code: nil,
            message: response.failureReason ?? "The provider did not include a failure reason."
          )
        case .queued, .dreaming, .unknown:
          let now = clock.now
          guard now < deadline else {
            throw ShipinError.generationTimedOut(provider: .lumaAI)
          }
          let remaining = now.duration(to: deadline)
          try await Task.sleep(for: min(pollInterval, remaining))
      }
    }
  }

  private func request(path: String, method: String) async throws -> URLRequest {
    try await request(pathComponents: [path], method: method, timeoutInterval: nil)
  }

  private func request(
    pathComponents: [String],
    method: String,
    timeoutInterval: TimeInterval? = nil
  ) async throws -> URLRequest {
    let url = pathComponents.reduce(baseURL) { url, component in
      url.appendingPathComponent(component)
    }
    return try await request(url: url, method: method, timeoutInterval: timeoutInterval)
  }

  private func request(
    url: URL,
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
    var request = URLRequest(url: url, timeoutInterval: timeoutInterval)
    request.httpMethod = method
    request.setValue(
      try await credential.authorizationHeaderValue(),
      forHTTPHeaderField: "Authorization"
    )
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
        provider: .lumaAI,
        statusCode: response.statusCode,
        message: decodeAPIErrorMessage(from: response.data),
        retryable: response.statusCode == 429 || (500...599).contains(response.statusCode)
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
        provider: .lumaAI,
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
