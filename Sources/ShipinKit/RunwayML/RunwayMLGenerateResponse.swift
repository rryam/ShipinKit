//
//  RunwayMLGenerateResponse.swift
//  ShipinKit
//
//  Created by Rudrank Riyam on 10/14/24.
//

import Foundation

/// Response model for image generation
public struct RunwayMLGenerateResponse: Codable, Sendable {
  let id: String
}

/// Response model for task details
public struct RunwayMLTaskResponse: Codable, Sendable {
  public let id: String
  public let status: RunwayMLTaskStatus
  public let createdAt: String
  public let progress: Double?
  public let output: [String]?
  public let failure: String?
  public let failureCode: String?
}

/// Task status enum
public enum RunwayMLTaskStatus: String, Codable, Sendable {
  case pending = "PENDING"
  case throttled = "THROTTLED"
  case running = "RUNNING"
  case succeeded = "SUCCEEDED"
  case failed = "FAILED"
}

/// Represents the aspect ratio options for generated videos.
///
/// - widescreen: 16:9 aspect ratio, suitable for landscape-oriented videos.
/// - portrait: 9:16 aspect ratio, suitable for portrait-oriented videos.
public enum RunwayMLAspectRatio: String, Codable, Sendable {
  case widescreen = "16:9"
  case portrait = "9:16"
}

/// Represents the duration options for generated videos.
///
/// - short: 5 seconds duration.
/// - long: 10 seconds duration.
public enum RunwayMLVideoDuration: Int, Codable, Sendable {
  case short = 5
  case long = 10
}
