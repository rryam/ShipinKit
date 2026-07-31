import Foundation

/// A provider selection with a redacted, lazily resolved credential.
public enum AIService: Sendable, CustomStringConvertible, CustomDebugStringConvertible {
  case lumaAI(credential: ShipinCredential)
  case runwayML(credential: ShipinCredential)

  public var provider: ShipinProvider {
    switch self {
      case .lumaAI: .lumaAI
      case .runwayML: .runwayML
    }
  }

  public var description: String {
    provider.rawValue
  }

  public var debugDescription: String {
    provider.rawValue
  }
}

/// Provider-specific generation requests accepted by ``ShipinClient``.
public enum ShipinGenerationRequest: Sendable {
  case lumaAI(LumaAIGenerationRequest)
  case runwayML(RunwayMLImageToVideoRequest)

  public var provider: ShipinProvider {
    switch self {
      case .lumaAI: .lumaAI
      case .runwayML: .runwayML
    }
  }
}

/// The typed immediate response returned after a generation is started.
public enum ShipinGenerationResponse: Sendable, Equatable {
  case lumaAI(LumaAIGeneration)
  case runwayML(RunwayMLCreateTaskResponse)
}

/// A small provider facade for applications that choose a service at runtime.
///
/// Applications with a fixed provider can use ``LumaAI`` or ``RunwayML``
/// directly for their fully provider-specific APIs.
public actor ShipinClient {
  private let service: AIService
  private let transport: any ShipinTransport
  private let requestTimeout: TimeInterval

  public init(
    service: AIService,
    transport: any ShipinTransport = URLSessionShipinTransport(),
    requestTimeout: TimeInterval = 60
  ) {
    self.service = service
    self.transport = transport
    self.requestTimeout = requestTimeout
  }

  /// Starts generation and returns a typed provider response instead of `Any`.
  public func generate(
    _ request: ShipinGenerationRequest
  ) async throws -> ShipinGenerationResponse {
    guard request.provider == service.provider else {
      throw ShipinError.providerMismatch(
        expected: service.provider,
        received: request.provider
      )
    }

    switch (service, request) {
      case (.lumaAI(let credential), .lumaAI(let generation)):
        let client = LumaAI(
          credential: credential,
          transport: transport,
          requestTimeout: requestTimeout
        )
        return .lumaAI(try await client.createGeneration(generation))
      case (.runwayML(let credential), .runwayML(let generation)):
        let client = RunwayML(
          credential: credential,
          transport: transport,
          requestTimeout: requestTimeout
        )
        return .runwayML(try await client.createImageToVideoTask(generation))
      case (.lumaAI, .runwayML), (.runwayML, .lumaAI):
        preconditionFailure("Provider mismatch must be handled before dispatch.")
    }
  }
}
