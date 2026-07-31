import Foundation

/// Current Runway-owned models supported by the image-to-video request type.
public enum RunwayMLVideoModel: String, Codable, Sendable, CaseIterable {
  /// Runway's highest-quality general video model.
  case gen45 = "gen4.5"
  /// Runway's faster image-to-video model.
  case gen4Turbo = "gen4_turbo"
}

/// Output resolutions accepted by Gen-4.5 and Gen-4 Turbo image-to-video.
public enum RunwayMLAspectRatio: String, Codable, Sendable, CaseIterable {
  case landscape = "1280:720"
  case portrait = "720:1280"
  case landscapeFourThree = "1104:832"
  case square = "960:960"
  case portraitFourThree = "832:1104"
  case cinematic = "1584:672"
}

/// A validated Runway video duration from 2 through 10 seconds.
public struct RunwayMLVideoDuration: RawRepresentable, Codable, Sendable, Equatable, Hashable {
  public let rawValue: Int

  public init?(rawValue: Int) {
    guard (2...10).contains(rawValue) else { return nil }
    self.rawValue = rawValue
  }

  public init(seconds: Int) throws {
    guard (2...10).contains(seconds) else {
      throw ShipinError.invalidRequest(
        field: "duration",
        reason: "Runway video duration must be between 2 and 10 seconds."
      )
    }
    self.rawValue = seconds
  }

  public static let fiveSeconds = Self(rawValue: 5)!
  public static let tenSeconds = Self(rawValue: 10)!
}

/// A validated input image accepted by Runway's API.
public struct RunwayMLImageSource: Sendable, Equatable, Hashable {
  let value: String

  /// Creates a source from a public HTTPS URL.
  public init(url: URL) throws {
    guard url.scheme?.lowercased() == "https" else {
      throw ShipinError.invalidRequest(
        field: "promptImage",
        reason: "Runway image URLs must use HTTPS."
      )
    }
    self.value = url.absoluteString
  }

  /// Creates a source from a URI returned by Runway's upload API.
  public init(runwayURI: String) throws {
    guard runwayURI.hasPrefix("runway://") else {
      throw ShipinError.invalidRequest(
        field: "promptImage",
        reason: "Runway upload URIs must start with runway://."
      )
    }
    self.value = runwayURI
  }

  /// Creates a source from image data. Runway currently accepts data URIs up to 5 MB.
  public init(data: Data, mimeType: String) throws {
    let parts = mimeType.split(separator: "/", omittingEmptySubsequences: false)
    let allowedSubtypeCharacters = CharacterSet.alphanumerics.union(
      CharacterSet(charactersIn: ".+-")
    )
    guard
      parts.count == 2,
      parts[0].lowercased() == "image",
      !parts[1].isEmpty,
      parts[1].unicodeScalars.allSatisfy(allowedSubtypeCharacters.contains)
    else {
      throw ShipinError.invalidRequest(
        field: "promptImage",
        reason: "The MIME type must be a valid image media type."
      )
    }
    let value = "data:image/\(parts[1].lowercased());base64,\(data.base64EncodedString())"
    guard value.utf8.count <= 5 * 1_024 * 1_024 else {
      throw ShipinError.invalidRequest(
        field: "promptImage",
        reason: "The encoded data URI must not exceed 5 MB."
      )
    }
    self.value = value
  }
}

extension RunwayMLImageSource: Encodable {
  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(value)
  }
}

/// Controls Runway's public-figure content-moderation threshold.
public enum RunwayMLPublicFigureThreshold: String, Codable, Sendable {
  case automatic = "auto"
  case low
}

public struct RunwayMLContentModeration: Codable, Sendable, Equatable {
  public let publicFigureThreshold: RunwayMLPublicFigureThreshold

  public init(publicFigureThreshold: RunwayMLPublicFigureThreshold = .automatic) {
    self.publicFigureThreshold = publicFigureThreshold
  }
}

/// A model-specific request for `POST /v1/image_to_video`.
public struct RunwayMLImageToVideoRequest: Encodable, Sendable, Equatable {
  public let model: RunwayMLVideoModel
  public let promptImage: RunwayMLImageSource
  public let promptText: String
  public let duration: RunwayMLVideoDuration
  public let ratio: RunwayMLAspectRatio
  public let seed: UInt32?
  public let contentModeration: RunwayMLContentModeration?

  public init(
    model: RunwayMLVideoModel = .gen4Turbo,
    promptImage: RunwayMLImageSource,
    promptText: String,
    duration: RunwayMLVideoDuration = .fiveSeconds,
    ratio: RunwayMLAspectRatio = .landscape,
    seed: UInt32? = nil,
    contentModeration: RunwayMLContentModeration? = nil
  ) throws {
    let promptLength = promptText.utf16.count
    guard (1...1_000).contains(promptLength) else {
      throw ShipinError.invalidRequest(
        field: "promptText",
        reason: "Runway prompts must contain 1 through 1000 UTF-16 code units."
      )
    }
    self.model = model
    self.promptImage = promptImage
    self.promptText = promptText
    self.duration = duration
    self.ratio = ratio
    self.seed = seed
    self.contentModeration = contentModeration
  }
}

/// The immediate response from starting a Runway task.
public struct RunwayMLCreateTaskResponse: Codable, Sendable, Equatable {
  public let id: String

  public init(id: String) {
    self.id = id
  }
}

/// The current lifecycle state of a Runway task.
public enum RunwayMLTaskStatus: String, Codable, Sendable, CaseIterable {
  case pending = "PENDING"
  case throttled = "THROTTLED"
  case cancelled = "CANCELLED"
  case running = "RUNNING"
  case failed = "FAILED"
  case succeeded = "SUCCEEDED"
}

/// A state-aware response from `GET /v1/tasks/{id}`.
public struct RunwayMLTaskResponse: Codable, Sendable, Equatable {
  public enum State: Sendable, Equatable {
    case pending
    case throttled
    case cancelled
    case running(progress: Double?)
    case failed(message: String?, code: String?)
    case succeeded(output: [URL])
  }

  public let id: String
  public let createdAt: Date
  public let state: State

  public var status: RunwayMLTaskStatus {
    switch state {
      case .pending: .pending
      case .throttled: .throttled
      case .cancelled: .cancelled
      case .running: .running
      case .failed: .failed
      case .succeeded: .succeeded
    }
  }

  public init(id: String, createdAt: Date, state: State) {
    self.id = id
    self.createdAt = createdAt
    self.state = state
  }

  private enum CodingKeys: String, CodingKey {
    case id
    case createdAt
    case status
    case progress
    case failure
    case failureCode
    case output
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(String.self, forKey: .id)
    let createdAtString = try container.decode(String.self, forKey: .createdAt)
    createdAt = try decodeShipinAPIDate(createdAtString, codingPath: decoder.codingPath)

    switch try container.decode(RunwayMLTaskStatus.self, forKey: .status) {
      case .pending:
        state = .pending
      case .throttled:
        state = .throttled
      case .cancelled:
        state = .cancelled
      case .running:
        state = .running(progress: try container.decodeIfPresent(Double.self, forKey: .progress))
      case .failed:
        state = .failed(
          message: try container.decodeIfPresent(String.self, forKey: .failure),
          code: try container.decodeIfPresent(String.self, forKey: .failureCode)
        )
      case .succeeded:
        state = .succeeded(output: try container.decode([URL].self, forKey: .output))
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(id, forKey: .id)
    try container.encode(encodeShipinAPIDate(createdAt), forKey: .createdAt)
    try container.encode(status, forKey: .status)

    switch state {
      case .running(let progress):
        try container.encode(progress, forKey: .progress)
      case .failed(let message, let code):
        try container.encode(message, forKey: .failure)
        try container.encodeIfPresent(code, forKey: .failureCode)
      case .succeeded(let output):
        try container.encode(output, forKey: .output)
      case .pending, .throttled, .cancelled:
        break
    }
  }
}

/// A completed Runway generation with its full task receipt and output URLs.
public struct RunwayMLGeneratedVideo: Sendable, Equatable {
  public let task: RunwayMLTaskResponse
  public let output: [URL]

  public init(task: RunwayMLTaskResponse, output: [URL]) {
    self.task = task
    self.output = output
  }
}

private func decodeShipinAPIDate(_ value: String, codingPath: [any CodingKey]) throws -> Date {
  let fractional = ISO8601DateFormatter()
  fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
  if let date = fractional.date(from: value) {
    return date
  }

  let standard = ISO8601DateFormatter()
  standard.formatOptions = [.withInternetDateTime]
  if let date = standard.date(from: value) {
    return date
  }

  throw DecodingError.dataCorrupted(
    .init(codingPath: codingPath, debugDescription: "Invalid ISO 8601 date: \(value)")
  )
}

private func encodeShipinAPIDate(_ value: Date) -> String {
  let formatter = ISO8601DateFormatter()
  formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
  return formatter.string(from: value)
}
