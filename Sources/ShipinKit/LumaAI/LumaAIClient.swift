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

  /// Retrieves a specific generation from the Luma AI API.
  ///
  /// - Parameter id: The unique identifier of the generation to retrieve.
  ///
  /// - Returns: A `LumaAIGenerationResponse` containing the details of the requested generation.
  ///
  /// - Throws: `LumaAIError.httpError` if the API request fails, or `LumaAIError.decodingError` if the response cannot be decoded.
  public func getGeneration(id: String) async throws -> LumaAIGenerationResponse {
    let url = baseURL.appendingPathComponent("/dream-machine/v1/generations/\(id)")
    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    request.addValue("application/json", forHTTPHeaderField: "accept")
    request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "authorization")

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

  /// Lists all generations from the Luma AI API with pagination support.
  ///
  /// - Parameters:
  ///   - limit: The maximum number of generations to return. Defaults to 10.
  ///   - offset: The number of generations to skip before starting to return results. Defaults to 0.
  ///
  /// - Returns: An array of `LumaAIGenerationResponse` objects representing the list of generations.
  ///
  /// - Throws: `LumaAIError.httpError` if the API request fails, or `LumaAIError.decodingError` if the response cannot be decoded.
  public func listGenerations(limit: Int = 10, offset: Int = 0) async throws -> [LumaAIGenerationResponse] {
    var components = URLComponents(url: baseURL.appendingPathComponent("/dream-machine/v1/generations"), resolvingAgainstBaseURL: true)
    components?.queryItems = [
      URLQueryItem(name: "limit", value: String(limit)),
      URLQueryItem(name: "offset", value: String(offset))
    ]

    guard let url = components?.url else {
      throw URLError(.badURL)
    }

    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    request.addValue("application/json", forHTTPHeaderField: "accept")
    request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "authorization")

    let (data, response) = try await session.data(for: request)

    if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
      throw LumaAIError.httpError(statusCode: httpResponse.statusCode)
    }

    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    do {
      let generationResponses = try decoder.decode([LumaAIGenerationResponse].self, from: data)
      return generationResponses
    } catch {
      throw LumaAIError.decodingError(underlying: error)
    }
  }

  /// Deletes a specific generation from the Luma AI API.
  ///
  /// - Parameter id: The unique identifier of the generation to delete.
  ///
  /// - Throws: `LumaAIError.httpError` if the API request fails.
  public func deleteGeneration(id: String) async throws {
    let url = baseURL.appendingPathComponent("/dream-machine/v1/generations/\(id)")
    var request = URLRequest(url: url)
    request.httpMethod = "DELETE"
    request.addValue("application/json", forHTTPHeaderField: "accept")
    request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "authorization")

    let (_, response) = try await session.data(for: request)

    if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
      throw LumaAIError.httpError(statusCode: httpResponse.statusCode)
    }
  }
}
