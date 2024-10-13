//
//  LumaAIGenerationResponse.swift
//  ShipinKit
//
//  Created by Rudrank Riyam on 10/13/24.
//

import Foundation

/// Represents the response from the Luma AI generation API.
public struct LumaAIGenerationResponse: Codable {
  public let id: String
  public let state: String
  public let failureReason: String?
  public let createdAt: String
  public let assets: LumaAIAssets
  public let version: String
  public let request: LumaAIGenerationRequest

  enum CodingKeys: String, CodingKey {
    case id
    case state
    case failureReason = "failure_reason"
    case createdAt = "created_at"
    case assets
    case version
    case request
  }
}

/// Contains the assets returned by the Luma AI generation API.
public struct LumaAIAssets: Codable {
  public let video: String
}

/// Represents the original request sent to the Luma AI generation API.
public struct LumaAIGenerationRequest: Codable {
  public let prompt: String
  public let aspectRatio: String
  public let loop: Bool
  public let keyframes: [String: LumaAIKeyframeData]
  public let callbackURL: String?

  enum CodingKeys: String, CodingKey {
    case prompt
    case aspectRatio = "aspect_ratio"
    case loop
    case keyframes
    case callbackURL = "callback_url"
  }
}

/// Represents keyframe data in the generation request.
public struct LumaAIKeyframeData: Codable {
  public let type: String
  public let url: String?
  public let id: String?
}
