//
//  LumaAIClient.swift
//  ShipinKit
//
//  Created by Rudrank Riyam on 10/13/24.
//

import Foundation

/// A client for interacting with the Luma AI API.
public class LumaAIClient {
  private let apiKey: String
  private let session: URLSession
  private let baseURL = URL(string: "https://api.lumalabs.ai")!

  /// Initializes a new instance of `LumaAIClient`
  ///
  /// - Parameters:
  ///   - apiKey: Your Luma AI API key.
  ///   - session: The URLSession to use for network requests. Defaults to `URLSession.shared`.
  public init(apiKey: String, session: URLSession = .shared) {
    self.apiKey = apiKey
    self.session = session
  }

  /// Initiates a generation request to the Luma AI API.
  ///
  /// - Parameters:
  ///   - prompt: The prompt for the generation.
  ///   - aspectRatio: The aspect ratio of the generated content. Defaults to "16:9".
  ///   - loop: Whether the generated content should loop.
  ///   - keyframes: A dictionary of keyframes.
  ///   - callbackURL: The callback URL to receive generation updates.
  ///
  /// - Returns: A `GenerationResponse` containing the result of the generation.
  public func createGeneration(prompt: String, aspectRatio: String = "16:9", loop: Bool, keyframes: [String: LumaAIKeyframeData], callbackURL: String? = nil) async throws -> LumaAIGenerationResponse {
    let url = baseURL.appendingPathComponent("/dream-machine/v1/generations")
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.timeoutInterval = 10
    request.addValue("application/json", forHTTPHeaderField: "accept")
    request.addValue("application/json", forHTTPHeaderField: "content-type")
    request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "authorization")

    let requestBody = LumaAIGenerationRequest(prompt: prompt, aspectRatio: aspectRatio, loop: loop, keyframes: keyframes, callbackURL: callbackURL)
    let encoder = JSONEncoder()
    encoder.keyEncodingStrategy = .convertToSnakeCase
    let bodyData = try encoder.encode(requestBody)
    request.httpBody = bodyData

    let (data, response) = try await session.data(for: request)

    if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
      throw LumaAIError.httpError(statusCode: httpResponse.statusCode)
    }

    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    do {
      let generationResponse = try decoder.decode(LumaAIGenerationResponse.self, from: data)
      return generationResponse
    } catch {
      throw LumaAIError.decodingError(underlying: error)
    }
  }
}
