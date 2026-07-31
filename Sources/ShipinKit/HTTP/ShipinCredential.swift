import Foundation

/// A lazily resolved API credential.
///
/// Use the provider initializer to read credentials from Keychain, an app-owned
/// secrets service, or another secure store at request time. String and debug
/// descriptions are always redacted.
public struct ShipinCredential: Sendable, CustomStringConvertible, CustomDebugStringConvertible {
  private let provider: @Sendable () async throws -> String

  /// Creates a credential from an API key already owned by the application.
  public init(apiKey: String) {
    self.provider = { apiKey }
  }

  /// Creates a credential whose value is resolved for every request.
  public init(provider: @escaping @Sendable () async throws -> String) {
    self.provider = provider
  }

  public var description: String { "<redacted>" }

  public var debugDescription: String { "<redacted>" }

  func authorizationHeaderValue() async throws -> String {
    let apiKey = try await provider()
    guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      throw ShipinError.missingCredential
    }
    return "Bearer \(apiKey)"
  }
}
