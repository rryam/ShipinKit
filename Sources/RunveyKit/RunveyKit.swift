import Foundation

#if canImport(UIKit)
import UIKit
#endif

#if canImport(AppKit)
import AppKit
#endif

#if os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
public typealias RunwayImage = UIImage
#elseif os(macOS)
public typealias RunwayImage = NSImage
#endif



// MARK: - RunwayML

/// Custom error types for RunwayML operations with localized descriptions and suggestions
public enum RunwayMLError: Error {
  case invalidURL
  case requestFailed(Error)
  case invalidResponse
  case decodingFailed
  case rateLimitExceeded
  case invalidSeed
  case imageTooLarge
  case badRequest
  case unauthorized
  case notFound
  case methodNotAllowed
  case serviceUnavailable
  case gatewayTimeout

  var localizedDescription: String {
    switch self {
      case .invalidURL:
        return "Invalid URL provided. Please check the URL and try again."
      case .requestFailed(let error):
        return "Request failed with error: \(error.localizedDescription). Check your network connection and try again."
      case .invalidResponse:
        return "Invalid response received from the server. Please try again later."
      case .decodingFailed:
        return "Failed to decode the response. This might be due to a server error. Please try again later."
      case .rateLimitExceeded:
        return "Rate limit exceeded. Please wait for a while before making another request."
      case .invalidSeed:
        return "Invalid seed provided. Seed must be between 0 and 999999999."
      case .imageTooLarge:
        return "Image size exceeds the maximum limit. Please reduce the image size and try again."
      case .badRequest:
        return "Bad request. Please check the request parameters and try again."
      case .unauthorized:
        return "Unauthorized access. Please check your API key and try again."
      case .notFound:
        return "Resource not found. Please check the URL and try again."
      case .methodNotAllowed:
        return "Method not allowed. Please check the HTTP method used and try again."
      case .serviceUnavailable:
        return "Service unavailable. Please try again later."
      case .gatewayTimeout:
        return "Gateway timeout. Please try again later."
    }
  }
}

public enum AspectRatio: String, Codable, Sendable {
  case widescreen = "WIDESCREEN"
  case square = "SQUARE"
}

public enum VideoDuration: Int, Codable, Sendable {
  case short = 5
  case long = 10
}

/// A struct that encapsulates the RunwayML REST API functionality
public struct RunveyKit {
  // MARK: - Constants

  public static let apiKey = "YOUR_API_KEY_HERE"
  public static let baseURL = URL(string: "https://api.runwayml.com/v1")!

  /// Response model for image generation
  public struct GenerateResponse: Codable, Sendable {
    let id: String
  }

  /// Response model for task details
  public struct TaskResponse: Codable, Sendable {
    public let id: String
    public let status: TaskStatus
    public let createdAt: Date
    public let progress: Double?
    public let output: [String]?
    public let failure: String?
    public let failureCode: String?
  }

  /// Task status enum
  public enum TaskStatus: String, Codable {
    case pending = "PENDING"
    case throttled = "THROTTLED"
    case running = "RUNNING"
    case succeeded = "SUCCEEDED"
    case failed = "FAILED"
  }

  // MARK: - API Methods
  /// Generates an image using the RunwayML API
  ///
  /// - Parameters:
  ///   - prompt: The text prompt for image generation
  ///   - imageURL: The URL of the input image
  ///   - duration: The duration of the generation process (default: .short)
  ///   - aspectRatio: The aspect ratio of the generated image (default: .widescreen)
  ///   - watermark: Whether to include a watermark (default: false)
  ///   - seed: An optional seed for randomization (default: nil, which lets the server generate a random seed)
  ///
  /// - Returns: The ID of the newly created task.
  /// - Throws: RunwayMLError
  ///
  /// - Example:
  ///   ```swift
  ///   import RunveyKit
  ///
  ///   do {
  ///       let prompt = "Dynamic tracking shot: The camera glides through the iconic Shibuya Crossing in Tokyo at night, capturing the bustling intersection bathed in vibrant neon lights. Countless pedestrians cross the wide intersection as towering digital billboards illuminate the scene with colorful advertisements. The wet pavement reflects the dazzling lights, creating a cinematic urban atmosphere."
  ///       let imageURL = URL(string: "https://images.unsplash.com/photo-1542051841857-5f90071e7989?q=80&w=3270&auto=format&fit=crop&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D")!
  ///
  ///       let taskID = try await RunwayML.generateImage(
  ///           prompt: prompt,
  ///           imageURL: imageURL,
  ///           duration: .long, // 10 seconds
  ///           aspectRatio: .widescreen, // 16:9 ratio
  ///           watermark: false,
  ///           seed: 42
  ///       )
  ///
  ///       print("Image generation task started with ID: \(taskID)")
  ///   } catch {
  ///       print("Error generating image: \(error)")
  ///   }
  ///   ```
  public static func generateImage(
    prompt: String,
    imageURL: URL,
    duration: VideoDuration = .short,
    aspectRatio: AspectRatio = .widescreen,
    watermark: Bool = false,
    seed: Int? = nil
  ) async throws -> String {
    let endpoint = baseURL.appendingPathComponent("generate")

    var request = URLRequest(url: endpoint)
    request.httpMethod = "POST"
    request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")

    if let seed = seed {
      guard (0...999999999).contains(seed) else {
        throw RunwayMLError.invalidSeed
      }
    }

    var body: [String: Any] = [
      "promptImage": imageURL.absoluteString,
      "model": "gen3a_turbo",
      "promptText": prompt,
      "watermark": watermark,
      "duration": duration.rawValue,
      "ratio": aspectRatio.rawValue
    ]

    if let seed = seed {
      body["seed"] = seed
    }

    request.httpBody = try JSONSerialization.data(withJSONObject: body)

    let (data, response) = try await URLSession.shared.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse else {
      throw RunwayMLError.invalidResponse
    }

    switch httpResponse.statusCode {
      case 200:
        let decoder = JSONDecoder()
        do {
          let generateResponse = try decoder.decode(GenerateResponse.self, from: data)
          return generateResponse.id
        } catch {
          throw RunwayMLError.decodingFailed
        }
      case 429:
        throw RunwayMLError.rateLimitExceeded
      case 400:
        throw RunwayMLError.badRequest
      case 401:
        throw RunwayMLError.unauthorized
      case 404:
        throw RunwayMLError.notFound
      case 405:
        throw RunwayMLError.methodNotAllowed
      case 502, 503, 504:
        throw RunwayMLError.serviceUnavailable
      default:
        throw RunwayMLError.invalidResponse
    }
  }

  /// Generates an image using the RunwayML API from a UIImage
  ///
  /// - Parameters:
  ///   - prompt: The text prompt for image generation
  ///   - image: The UIImage to generate the image from
  ///   - duration: The duration of the generation process (default: .short)
  ///   - aspectRatio: The aspect ratio of the generated image (default: .widescreen)
  ///   - watermark: Whether to include a watermark (default: false)
  ///   - seed: An optional seed for randomization (default: nil, which lets the server generate a random seed)
  ///
  /// - Returns: The ID of the newly created task.
  /// - Throws: RunwayMLError
  public static func generateImage(
    prompt: String,
    image: RunwayImage,
    duration: VideoDuration = .short,
    aspectRatio: AspectRatio = .widescreen,
    watermark: Bool = false,
    seed: Int? = nil
  ) async throws -> String {
    let base64String = try imageToBase64String(image)
    let dataURI = "data:image/jpeg;base64," + base64String
    let imageURL = URL(string: dataURI)!
    return try await generateImage(prompt: prompt, imageURL: imageURL, duration: duration, aspectRatio: aspectRatio, watermark: watermark, seed: seed)
  }

  /// Converts a UIImage to a base64 string for use in data URIs
  ///
  /// - Parameter image: The UIImage to convert
  /// - Returns: A base64 string representation of the image
  ///
  /// - Throws: RunwayMLError if the image is too large
  public static func imageToBase64String(_ image: RunwayImage) throws -> String {
    let imageData: Data
    #if os(macOS)
    guard let tiffRepresentation = image.tiffRepresentation,
          let bitmapImage = NSBitmapImageRep(data: tiffRepresentation),
          let jpegData = bitmapImage.representation(using: .jpeg, properties: [:]) else {
      throw RunwayMLError.requestFailed(NSError(domain: "Image conversion failed", code: 0, userInfo: nil))
    }
    imageData = jpegData
    #else
    guard let jpegData = image.jpegData(compressionQuality: 1) else {
      throw RunwayMLError.requestFailed(NSError(domain: "Image conversion failed", code: 0, userInfo: nil))
    }
    imageData = jpegData
    #endif

    let base64String = imageData.base64EncodedString()

    // Check if the base64 string is under the 3MB limit
    let base64Data = Data(base64String.utf8)
    if base64Data.count > 3 * 1024 * 1024 {
      throw RunwayMLError.imageTooLarge
    }
    return base64String
  }

  /// Gets details about a task
  ///
  /// - Parameter id: The ID of the task to retrieve
  /// - Returns: A TaskResponse object containing task details
  /// - Throws: RunwayMLError
  public static func getTaskDetails(id: String) async throws -> TaskResponse {
    let endpoint = baseURL.appendingPathComponent("tasks/\(id)")

    var request = URLRequest(url: endpoint)
    request.httpMethod = "GET"
    request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    request.addValue("2024-09-13", forHTTPHeaderField: "X-Runway-Version")

    let (data, response) = try await URLSession.shared.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse else {
      throw RunwayMLError.invalidResponse
    }

    switch httpResponse.statusCode {
      case 200:
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
          let taskResponse = try decoder.decode(TaskResponse.self, from: data)
          return taskResponse
        } catch {
          throw RunwayMLError.decodingFailed
        }
      case 429:
        throw RunwayMLError.rateLimitExceeded
      case 400:
        throw RunwayMLError.badRequest
      case 401:
        throw RunwayMLError.unauthorized
      case 404:
        throw RunwayMLError.notFound
      case 405:
        throw RunwayMLError.methodNotAllowed
      case 502, 503, 504:
        throw RunwayMLError.serviceUnavailable
      default:
        throw RunwayMLError.invalidResponse
    }
  }

  /// Processes the task response and returns a human-readable description
  ///
  /// - Parameter task: The TaskResponse object to process
  /// - Returns: A string describing the task status and details
  public static func processTaskResponse(_ task: TaskResponse) -> String {
    switch task.status {
      case .pending:
        return "Task \(task.id) is pending. Created at: \(task.createdAt)"
      case .throttled:
        return "Task \(task.id) is throttled. Created at: \(task.createdAt)"
      case .running:
        let progress = task.progress.map { String(format: "%.0f%%", $0 * 100) } ?? "Unknown"
        return "Task \(task.id) is running. Progress: \(progress). Created at: \(task.createdAt)"
      case .succeeded:
        let outputs = task.output?.joined(separator: ", ") ?? "No outputs available"
        return "Task \(task.id) has succeeded. Outputs: \(outputs). Created at: \(task.createdAt)"
      case .failed:
        let failure = task.failure ?? "Unknown error"
        let failureCode = task.failureCode ?? "No failure code"
        return "Task \(task.id) has failed. Reason: \(failure). Failure code: \(failureCode). Created at: \(task.createdAt)"
    }
  }

  /// Cancels or deletes a task
  ///
  /// - Parameter id: The ID of the task to cancel or delete
  /// - Throws: RunwayMLError
  public static func cancelOrDeleteTask(id: String) async throws {
    let endpoint = baseURL.appendingPathComponent("tasks/\(id)")

    var request = URLRequest(url: endpoint)
    request.httpMethod = "DELETE"
    request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    request.addValue("2024-09-13", forHTTPHeaderField: "X-Runway-Version")

    let (_, response) = try await URLSession.shared.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse else {
      throw RunwayMLError.invalidResponse
    }

    switch httpResponse.statusCode {
      case 204:
        return // Task successfully canceled or deleted
      case 429:
        throw RunwayMLError.rateLimitExceeded
      case 400:
        throw RunwayMLError.badRequest
      case 401:
        throw RunwayMLError.unauthorized
      case 404:
        throw RunwayMLError.notFound
      case 405:
        throw RunwayMLError.methodNotAllowed
      case 502, 503, 504:
        throw RunwayMLError.serviceUnavailable
      default:
        throw RunwayMLError.invalidResponse
    }
  }
}
