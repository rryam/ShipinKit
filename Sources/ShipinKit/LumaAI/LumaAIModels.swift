import Foundation

/// Current Luma video-generation models.
public enum LumaAIModel: String, Codable, Sendable, CaseIterable {
  case ray2 = "ray-2"
  case rayFlash2 = "ray-flash-2"
}

public enum LumaAIAspectRatio: String, Codable, Sendable, CaseIterable {
  case square = "1:1"
  case landscape = "16:9"
  case portrait = "9:16"
  case landscapeFourThree = "4:3"
  case portraitFourThree = "3:4"
  case landscapeWide = "21:9"
  case portraitTall = "9:21"
}

/// A Luma resolution, preserving values introduced after this SDK release.
public enum LumaAIResolution: Codable, Sendable, Equatable {
  case p540
  case p720
  case p1080
  case k4
  case custom(String)

  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    let value = try container.decode(String.self)
    self = switch value {
      case "540p": .p540
      case "720p": .p720
      case "1080p": .p1080
      case "4k": .k4
      default: .custom(value)
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    let value = switch self {
      case .p540: "540p"
      case .p720: "720p"
      case .p1080: "1080p"
      case .k4: "4k"
      case .custom(let value): value
    }
    try container.encode(value)
  }
}

/// A Luma duration, preserving values introduced after this SDK release.
public enum LumaAIDuration: Codable, Sendable, Equatable {
  case fiveSeconds
  case nineSeconds
  case custom(String)

  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    let value = try container.decode(String.self)
    self = switch value {
      case "5s": .fiveSeconds
      case "9s": .nineSeconds
      default: .custom(value)
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    let value = switch self {
      case .fiveSeconds: "5s"
      case .nineSeconds: "9s"
      case .custom(let value): value
    }
    try container.encode(value)
  }
}

public enum LumaAIGenerationType: String, Codable, Sendable {
  case video
}

public struct LumaAIConcept: Codable, Sendable, Equatable {
  public let key: String

  public init(key: String) throws {
    guard !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      throw ShipinError.invalidRequest(field: "concept.key", reason: "Concept keys cannot be empty.")
    }
    self.key = key
  }
}

/// A start/end frame used by Luma video generation.
public enum LumaAIKeyframe: Codable, Sendable, Equatable {
  case image(URL)
  case generation(id: String)

  private enum CodingKeys: String, CodingKey {
    case type
    case url
    case id
  }

  private enum Kind: String, Codable {
    case image
    case generation
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    switch try container.decode(Kind.self, forKey: .type) {
      case .image:
        self = .image(try container.decode(URL.self, forKey: .url))
      case .generation:
        self = .generation(id: try container.decode(String.self, forKey: .id))
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    switch self {
      case .image(let url):
        try container.encode(Kind.image, forKey: .type)
        try container.encode(url, forKey: .url)
      case .generation(let id):
        try container.encode(Kind.generation, forKey: .type)
        try container.encode(id, forKey: .id)
    }
  }
}

public struct LumaAIKeyframes: Codable, Sendable, Equatable {
  public let frame0: LumaAIKeyframe?
  public let frame1: LumaAIKeyframe?

  public init(frame0: LumaAIKeyframe? = nil, frame1: LumaAIKeyframe? = nil) throws {
    guard frame0 != nil || frame1 != nil else {
      throw ShipinError.invalidRequest(
        field: "keyframes",
        reason: "At least one Luma keyframe must be provided."
      )
    }
    self.frame0 = frame0
    self.frame1 = frame1
  }
}

/// A typed request for Luma's current video-generation endpoint.
public struct LumaAIGenerationRequest: Encodable, Sendable, Equatable {
  public let generationType: LumaAIGenerationType
  public let prompt: String?
  public let model: LumaAIModel
  public let resolution: LumaAIResolution?
  public let duration: LumaAIDuration?
  public let aspectRatio: LumaAIAspectRatio?
  public let loop: Bool?
  public let keyframes: LumaAIKeyframes?
  public let callbackURL: URL?
  public let concepts: [LumaAIConcept]?

  public init(
    prompt: String? = nil,
    model: LumaAIModel = .ray2,
    resolution: LumaAIResolution? = nil,
    duration: LumaAIDuration? = nil,
    aspectRatio: LumaAIAspectRatio? = nil,
    loop: Bool? = nil,
    keyframes: LumaAIKeyframes? = nil,
    callbackURL: URL? = nil,
    concepts: [LumaAIConcept]? = nil
  ) throws {
    if let prompt, prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      throw ShipinError.invalidRequest(
        field: "prompt",
        reason: "When supplied, the Luma prompt cannot be blank."
      )
    }
    if loop == true, keyframes?.frame0 != nil, keyframes?.frame1 != nil {
      throw ShipinError.invalidRequest(
        field: "loop",
        reason: "Luma does not support looping with both start and end keyframes."
      )
    }
    self.generationType = .video
    self.prompt = prompt
    self.model = model
    self.resolution = resolution
    self.duration = duration
    self.aspectRatio = aspectRatio
    self.loop = loop
    self.keyframes = keyframes
    self.callbackURL = callbackURL
    self.concepts = concepts
  }

  private enum CodingKeys: String, CodingKey {
    case generationType = "generation_type"
    case prompt
    case model
    case resolution
    case duration
    case aspectRatio = "aspect_ratio"
    case loop
    case keyframes
    case callbackURL = "callback_url"
    case concepts
  }
}

/// A forward-compatible Luma generation state.
public enum LumaAIGenerationState: Codable, Sendable, Equatable {
  case queued
  case dreaming
  case completed
  case failed
  case unknown(String)

  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    let value = try container.decode(String.self)
    switch value {
      case "queued": self = .queued
      case "dreaming": self = .dreaming
      case "completed": self = .completed
      case "failed": self = .failed
      default: self = .unknown(value)
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    let value: String = switch self {
      case .queued: "queued"
      case .dreaming: "dreaming"
      case .completed: "completed"
      case .failed: "failed"
      case .unknown(let value): value
    }
    try container.encode(value)
  }
}

public struct LumaAIAssets: Codable, Sendable, Equatable {
  public let image: URL?
  public let progressVideo: URL?
  public let video: URL?

  public init(image: URL? = nil, progressVideo: URL? = nil, video: URL? = nil) {
    self.image = image
    self.progressVideo = progressVideo
    self.video = video
  }

  private enum CodingKeys: String, CodingKey {
    case image
    case progressVideo = "progress_video"
    case video
  }
}

/// The request metadata echoed by Luma in a generation response.
public struct LumaAIGenerationRequestSnapshot: Codable, Sendable, Equatable {
  public let generationType: String?
  public let prompt: String?
  public let model: String?
  public let resolution: String?
  public let duration: String?
  public let aspectRatio: String?
  public let loop: Bool?
  public let keyframes: LumaAIKeyframes?
  public let callbackURL: URL?
  public let concepts: [LumaAIConcept]?

  private enum CodingKeys: String, CodingKey {
    case generationType = "generation_type"
    case prompt
    case model
    case resolution
    case duration
    case aspectRatio = "aspect_ratio"
    case loop
    case keyframes
    case callbackURL = "callback_url"
    case concepts
  }
}

/// A single Luma generation returned by create and get operations.
public struct LumaAIGeneration: Codable, Sendable, Equatable {
  public let id: String?
  public let state: LumaAIGenerationState?
  public let failureReason: String?
  public let createdAt: Date?
  public let assets: LumaAIAssets?
  public let generationType: String?
  public let model: String?
  public let request: LumaAIGenerationRequestSnapshot?

  public init(
    id: String? = nil,
    state: LumaAIGenerationState? = nil,
    failureReason: String? = nil,
    createdAt: Date? = nil,
    assets: LumaAIAssets? = nil,
    generationType: String? = nil,
    model: String? = nil,
    request: LumaAIGenerationRequestSnapshot? = nil
  ) {
    self.id = id
    self.state = state
    self.failureReason = failureReason
    self.createdAt = createdAt
    self.assets = assets
    self.generationType = generationType
    self.model = model
    self.request = request
  }

  private enum CodingKeys: String, CodingKey {
    case id
    case state
    case failureReason = "failure_reason"
    case createdAt = "created_at"
    case assets
    case generationType = "generation_type"
    case model
    case request
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decodeIfPresent(String.self, forKey: .id)
    state = try container.decodeIfPresent(LumaAIGenerationState.self, forKey: .state)
    failureReason = try container.decodeIfPresent(String.self, forKey: .failureReason)
    if let createdAtString = try container.decodeIfPresent(String.self, forKey: .createdAt) {
      createdAt = try decodeLumaAPIDate(createdAtString, codingPath: decoder.codingPath)
    } else {
      createdAt = nil
    }
    assets = try container.decodeIfPresent(LumaAIAssets.self, forKey: .assets)
    generationType = try container.decodeIfPresent(String.self, forKey: .generationType)
    model = try container.decodeIfPresent(String.self, forKey: .model)
    request = try container.decodeIfPresent(LumaAIGenerationRequestSnapshot.self, forKey: .request)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encodeIfPresent(id, forKey: .id)
    try container.encodeIfPresent(state, forKey: .state)
    try container.encodeIfPresent(failureReason, forKey: .failureReason)
    if let createdAt {
      try container.encode(encodeLumaAPIDate(createdAt), forKey: .createdAt)
    }
    try container.encodeIfPresent(assets, forKey: .assets)
    try container.encodeIfPresent(generationType, forKey: .generationType)
    try container.encodeIfPresent(model, forKey: .model)
    try container.encodeIfPresent(request, forKey: .request)
  }
}

/// The pagination envelope returned by Luma's list endpoint.
public struct LumaAIGenerationList: Codable, Sendable, Equatable {
  public let hasMore: Bool?
  public let count: Int?
  public let limit: Int?
  public let offset: Int?
  public let generations: [LumaAIGeneration]

  public init(
    hasMore: Bool? = nil,
    count: Int? = nil,
    limit: Int? = nil,
    offset: Int? = nil,
    generations: [LumaAIGeneration]
  ) {
    self.hasMore = hasMore
    self.count = count
    self.limit = limit
    self.offset = offset
    self.generations = generations
  }

  private enum CodingKeys: String, CodingKey {
    case hasMore = "has_more"
    case count
    case limit
    case offset
    case generations
  }
}

/// A completed Luma generation with its durable typed receipt.
public struct LumaAIGeneratedVideo: Sendable, Equatable {
  public let generation: LumaAIGeneration
  public let videoURL: URL

  public init(generation: LumaAIGeneration, videoURL: URL) {
    self.generation = generation
    self.videoURL = videoURL
  }
}

private func decodeLumaAPIDate(_ value: String, codingPath: [any CodingKey]) throws -> Date {
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

private func encodeLumaAPIDate(_ value: Date) -> String {
  let formatter = ISO8601DateFormatter()
  formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
  return formatter.string(from: value)
}
