//
//  ShipinKit.swift
//  ShipinKit
//
//  Created by Rudrank Riyam on 10/14/24.
//

import Foundation

/// Represents the choice of AI service to use in ShipinKit.
public enum AIService {
  case lumaAI(apiKey: String)
  case runwayML(apiKey: String)
}

/// ShipinKit: A unified interface for any AI service client.
public actor ShipinKit {

  /// The chosen AI service client.
  private let service: AIService

  /// Initializes a new instance of ShipinKit.
  ///
  /// - Parameter service: The AI service to use. This can be any service that conforms to the `AIService` protocol.
  ///
  /// - Returns: A new instance of ShipinKit.
  public init(service: AIService) {
    self.service = service
  }

  /// Generates content using the chosen AI service.
  ///
  /// This method adapts to the chosen AI service (LumaAI or RunwayML) and generates content based on the provided parameters.
  ///
  /// - Parameters:
  ///   - prompt: A `String` representing the prompt for generation.
  ///   - aspectRatio: A `String` specifying the aspect ratio of the generated content. Defaults to "16:9".
  ///   - loop: An optional `Bool` indicating whether the generated content should loop (only applicable for LumaAI).
  ///   - keyframes: An optional dictionary of keyframes (only applicable for LumaAI).
  ///   - image: An optional `@Sendable` closure returning a `ShipinImage` object representing the input image (only applicable for RunwayML).
  ///   - duration: An optional `RunwayMLVideoDuration` specifying the desired duration of the video (only applicable for RunwayML).
  ///   - watermark: An optional `Bool` indicating whether to include a watermark (only applicable for RunwayML).
  ///   - seed: An optional `Int` seed for reproducible results (only applicable for RunwayML).
  ///
  /// - Returns: Either a `LumaAIGenerationResponse` or a `URL`, depending on the chosen service.
  /// - Throws: A `ShipinKitError` if the generation fails or if incompatible parameters are provided for the chosen service.
  public func generate(
    prompt: String,
    aspectRatio: String = "16:9",
    loop: Bool? = nil,
    keyframes: [String: LumaAIKeyframeData]? = nil,
    image: (@Sendable () -> ShipinImage)? = nil,
    duration: RunwayMLVideoDuration? = nil,
    watermark: Bool? = nil,
    seed: Int? = nil
  ) async throws -> Any {
    switch service {
      case .lumaAI(let apiKey):
        let lumaAI = LumaAI(apiKey: apiKey)

        guard let loop = loop, let keyframes = keyframes else {
          throw ShipinKitError.invalidParameters
        }

        return try await lumaAI.createGeneration(
          prompt: prompt,
          aspectRatio: aspectRatio,
          loop: loop,
          keyframes: keyframes
        )
      case .runwayML(let apiKey):
        let runwayML = RunwayML(apiKey: apiKey)

        guard let imageClosure = image else {
          throw ShipinKitError.invalidParameters
        }

        return try await runwayML.generateVideo(
          prompt: prompt,
          image: imageClosure(),
          duration: duration ?? .short,
          aspectRatio: RunwayMLAspectRatio(rawValue: aspectRatio) ?? .widescreen,
          watermark: watermark ?? false,
          seed: seed
        )
    }
  }
}

/// Errors that can occur when using ShipinKit.
public enum ShipinKitError: Error {
  case invalidParameters
}
