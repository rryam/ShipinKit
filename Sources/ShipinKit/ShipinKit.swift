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

/// ShipinKit: A unified interface for either LumaAI or RunwayML client.
public struct ShipinKit {
  /// The chosen AI service client.
  private let service: Any
  
  /// The type of AI service being used.
  public let serviceType: AIService
  
  /// Initializes a new instance of ShipinKit.
  ///
  /// - Parameter service: The AI service to use, either LumaAI or RunwayML.
  ///
  /// - Returns: A new instance of ShipinKit.
  public init(service: AIService) {
    self.serviceType = service
    switch service {
    case .lumaAI(let apiKey):
      self.service = LumaAI(apiKey: apiKey)
    case .runwayML(let apiKey):
      self.service = RunwayML(apiKey: apiKey)
    }
  }
  
  /// Generates content using the chosen AI service.
  ///
  /// - Parameters:
  ///   - prompt: The prompt for generation.
  ///   - aspectRatio: The aspect ratio of the generated content.
  ///   - loop: Whether the generated content should loop (only applicable for LumaAI).
  ///   - keyframes: A dictionary of keyframes (only applicable for LumaAI).
  ///   - image: A `ShipinImage` object representing the input image (only applicable for RunwayML).
  ///   - duration: The desired duration of the video (only applicable for RunwayML).
  ///   - watermark: A boolean indicating whether to include a watermark (only applicable for RunwayML).
  ///   - seed: An optional integer seed for reproducible results (only applicable for RunwayML).
  ///
  /// - Returns: Either a `LumaAIGenerationResponse` or a `URL`, depending on the chosen service.
  /// - Throws: An error if the generation fails or if incompatible parameters are provided for the chosen service.
  public func generate(
    prompt: String,
    aspectRatio: String = "16:9",
    loop: Bool? = nil,
    keyframes: [String: LumaAIKeyframeData]? = nil,
    image: ShipinImage? = nil,
    duration: RunwayMLVideoDuration? = nil,
    watermark: Bool? = nil,
    seed: Int? = nil
  ) async throws -> Any {
    switch serviceType {
    case .lumaAI:
      guard let lumaAI = service as? LumaAI,
            let loop = loop,
            let keyframes = keyframes else {
        throw ShipinKitError.invalidParameters
      }
      return try await lumaAI.createGeneration(
        prompt: prompt,
        aspectRatio: aspectRatio,
        loop: loop,
        keyframes: keyframes
      )
    case .runwayML:
      guard let runwayML = service as? RunwayML,
            let image = image else {
        throw ShipinKitError.invalidParameters
      }
      return try await runwayML.generateVideo(
        prompt: prompt,
        image: image,
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
