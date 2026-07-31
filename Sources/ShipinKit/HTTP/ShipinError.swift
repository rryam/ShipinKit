import Foundation

/// Providers supported by ShipinKit.
public enum ShipinProvider: String, Sendable, Codable, CaseIterable {
  case lumaAI = "luma-ai"
  case runwayML = "runway-ml"
}

/// Errors produced by ShipinKit before, during, or after an HTTP request.
public enum ShipinError: Error, Sendable, Equatable {
  case missingCredential
  case invalidRequest(field: String, reason: String)
  case providerMismatch(expected: ShipinProvider, received: ShipinProvider)
  case invalidHTTPResponse
  case transportFailure(String)
  case responseDecodingFailed(provider: ShipinProvider, reason: String)
  case api(provider: ShipinProvider, statusCode: Int, message: String?, retryable: Bool)
  case generationFailed(provider: ShipinProvider, code: String?, message: String)
  case generationCancelled(provider: ShipinProvider)
  case generationTimedOut(provider: ShipinProvider)
  case missingOutput(provider: ShipinProvider)
  case missingResponseField(provider: ShipinProvider, field: String)
}

extension ShipinError: LocalizedError {
  public var errorDescription: String? {
    switch self {
      case .missingCredential:
        "The API credential is missing."
      case .invalidRequest(let field, let reason):
        "Invalid \(field): \(reason)"
      case .providerMismatch(let expected, let received):
        "The client is configured for \(expected.rawValue), but received a \(received.rawValue) request."
      case .invalidHTTPResponse:
        "The server returned a non-HTTP response."
      case .transportFailure(let reason):
        "The network request failed: \(reason)"
      case .responseDecodingFailed(let provider, let reason):
        "Could not decode the \(provider.rawValue) response: \(reason)"
      case .api(let provider, let statusCode, let message, _):
        message ?? "\(provider.rawValue) returned HTTP \(statusCode)."
      case .generationFailed(let provider, _, let message):
        "\(provider.rawValue) generation failed: \(message)"
      case .generationCancelled(let provider):
        "\(provider.rawValue) generation was cancelled."
      case .generationTimedOut(let provider):
        "Timed out waiting for \(provider.rawValue) generation."
      case .missingOutput(let provider):
        "\(provider.rawValue) reported success without an output URL."
      case .missingResponseField(let provider, let field):
        "\(provider.rawValue) returned a response without its \(field) field."
    }
  }
}

struct ShipinAPIErrorEnvelope: Decodable {
  let error: String?
  let message: String?
  let detail: ShipinAPIErrorDetail?

  var bestMessage: String? {
    error ?? message ?? detail?.message
  }
}

enum ShipinAPIErrorDetail: Decodable {
  case message(String)
  case validationIssues([ShipinAPIValidationIssue])

  var message: String? {
    switch self {
      case .message(let message):
        message
      case .validationIssues(let issues):
        issues.compactMap(\.message).joined(separator: "; ").nilIfEmpty
    }
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    if let message = try? container.decode(String.self) {
      self = .message(message)
    } else {
      self = .validationIssues(try container.decode([ShipinAPIValidationIssue].self))
    }
  }
}

struct ShipinAPIValidationIssue: Decodable {
  let message: String?

  private enum CodingKeys: String, CodingKey {
    case message = "msg"
  }
}

func decodeAPIErrorMessage(from data: Data) -> String? {
  guard !data.isEmpty else { return nil }
  if let envelope = try? JSONDecoder().decode(ShipinAPIErrorEnvelope.self, from: data) {
    return envelope.bestMessage
  }
  return nil
}

func validatePathIdentifier(_ id: String, field: String) throws {
  let trimmed = id.trimmingCharacters(in: .whitespacesAndNewlines)
  let forbiddenCharacters = CharacterSet(charactersIn: "/\\?#%")
  guard
    !trimmed.isEmpty,
    trimmed == id,
    trimmed != ".",
    trimmed != "..",
    trimmed.rangeOfCharacter(from: forbiddenCharacters) == nil
  else {
    throw ShipinError.invalidRequest(
      field: field,
      reason: "Identifiers must be a non-empty URL path segment."
    )
  }
}

private extension String {
  var nilIfEmpty: String? {
    isEmpty ? nil : self
  }
}
