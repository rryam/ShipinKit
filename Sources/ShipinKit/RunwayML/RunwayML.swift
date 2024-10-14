//
//  RunwayML.swift
//  ShipinKit
//
//  Created by Rudrank Riyam on 14/10/24.
//

import Foundation
import os

#if canImport(UIKit)
import UIKit
#endif

#if canImport(AppKit)
import AppKit
#endif

/// An actor that encapsulates the RunwayML REST API functionality
public actor RunwayML {
  private let apiKey: String
  private let baseURL = URL(string: "https://api.dev.runwayml.com/v1")!
  private let logger = Logger(subsystem: "com.runveykit", category: "API")

  public init(apiKey: String) {
    self.apiKey = apiKey
    logger.info("ShipinKit initialized with API key: \(apiKey)")
  }

  /// Generates a task using the RunwayML API
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
  ///   import ShipinKit
  ///
  ///   do {
  ///       let shipinKit = ShipinKit(apiKey: "YOUR_API_KEY_HERE")
  ///       let prompt = "Dynamic tracking shot: The camera glides through the iconic Shibuya Crossing in Tokyo at night, capturing the bustling intersection bathed in vibrant neon lights. Countless pedestrians cross the wide intersection as towering digital billboards illuminate the scene with colorful advertisements. The wet pavement reflects the dazzling lights, creating a cinematic urban atmosphere."
  ///       let imageURL = URL(string: "https://images.unsplash.com/photo-1542051841857-5f90071e7989?q=80&w=3270&auto=format&fit=crop&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D")!
  ///
  ///       let taskID = try await shipinKit.generateTask(
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
  public func generateTask(
    prompt: String,
    imageURL: URL,
    duration: RunwayMLVideoDuration = .short,
    aspectRatio: RunwayMLAspectRatio = .widescreen,
    watermark: Bool = false,
    seed: Int? = nil
  ) async throws -> String {
    logger.info("Generating image with prompt: \(prompt), imageURL: \(imageURL.absoluteString), duration: \(duration.rawValue), aspectRatio: \(aspectRatio.rawValue), watermark: \(watermark)")

    let endpoint = baseURL.appendingPathComponent("image_to_video")

    var request = URLRequest(url: endpoint)
    request.httpMethod = "POST"
    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("2024-09-13", forHTTPHeaderField: "X-Runway-Version")

    if let seed = seed {
      guard (0...999999999).contains(seed) else {
        logger.error("Invalid seed provided: \(seed)")
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

    logger.debug("Sending request to \(endpoint.absoluteString)")
    let (data, response) = try await URLSession.shared.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse else {
      logger.error("Invalid response received")
      throw RunwayMLError.invalidResponse
    }

    logger.info("Received response with status code: \(httpResponse.statusCode)")

    switch httpResponse.statusCode {
      case 200:
        let decoder = JSONDecoder()
        do {
          let generateResponse = try decoder.decode(RunwayMLGenerateResponse.self, from: data)
          logger.info("Successfully generated image with task ID: \(generateResponse.id)")
          return generateResponse.id
        } catch {
          logger.error("Failed to decode response: \(error.localizedDescription)")
          throw RunwayMLError.decodingFailed
        }
      case 429:
        logger.warning("Rate limit exceeded")
        throw RunwayMLError.rateLimitExceeded
      case 400:
        logger.error("Bad request")
        throw RunwayMLError.badRequest
      case 401:
        logger.error("Unauthorized access")
        throw RunwayMLError.unauthorized
      case 404:
        logger.error("Resource not found")
        throw RunwayMLError.notFound
      case 405:
        logger.error("Method not allowed")
        throw RunwayMLError.methodNotAllowed
      case 502, 503, 504:
        logger.error("Service unavailable")
        throw RunwayMLError.serviceUnavailable
      default:
        logger.error("Unexpected status code: \(httpResponse.statusCode)")
        throw RunwayMLError.invalidResponse
    }
  }

  /// Generates a task using the RunwayML API from a UIImage
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
  public func generateTask(
    prompt: String,
    image: ShipinImage,
    duration: RunwayMLVideoDuration = .short,
    aspectRatio: RunwayMLAspectRatio = .widescreen,
    watermark: Bool = false,
    seed: Int? = nil
  ) async throws -> String {
    logger.info("Generating image from RunwayImage")
    let base64String = try imageToBase64String(image)
    let dataURI = "data:image/jpeg;base64," + base64String
    let imageURL = URL(string: dataURI)!
    return try await generateTask(prompt: prompt, imageURL: imageURL, duration: duration, aspectRatio: aspectRatio, watermark: watermark, seed: seed)
  }

  /// Converts a UIImage to a base64 string for use in data URIs
  ///
  /// - Parameter image: The UIImage to convert
  /// - Returns: A base64 string representation of the image
  ///
  /// - Throws: RunwayMLError if the image is too large
  public func imageToBase64String(_ image: ShipinImage) throws -> String {
    logger.debug("Converting RunwayImage to base64 string")
    let imageData: Data
#if os(macOS)
    guard let tiffRepresentation = image.tiffRepresentation,
          let bitmapImage = NSBitmapImageRep(data: tiffRepresentation),
          let jpegData = bitmapImage.representation(using: .jpeg, properties: [:]) else {
      logger.error("Failed to convert NSImage to JPEG data")
      throw RunwayMLError.requestFailed(NSError(domain: "Image conversion failed", code: 0, userInfo: nil))
    }
    imageData = jpegData
#else
    guard let jpegData = image.jpegData(compressionQuality: 1) else {
      logger.error("Failed to convert UIImage to JPEG data")
      throw RunwayMLError.requestFailed(NSError(domain: "Image conversion failed", code: 0, userInfo: nil))
    }
    imageData = jpegData
#endif

    let base64String = imageData.base64EncodedString()

    // Check if the base64 string is under the 3MB limit
    let base64Data = Data(base64String.utf8)
    if base64Data.count > 3 * 1024 * 1024 {
      logger.error("Image size exceeds 3MB limit: \(base64Data.count) bytes")
      throw RunwayMLError.imageTooLarge
    }
    logger.debug("Successfully converted image to base64 string")
    return base64String
  }

  /// Gets details about a task
  ///
  /// - Parameter id: The ID of the task to retrieve
  /// - Returns: A TaskResponse object containing task details
  /// - Throws: RunwayMLError
  public func getTaskDetails(id: String) async throws -> RunwayMLTaskResponse {
    logger.info("Getting task details for task ID: \(id)")
    let endpoint = baseURL.appendingPathComponent("tasks/\(id)")

    var request = URLRequest(url: endpoint)
    request.httpMethod = "GET"
    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    request.setValue("2024-09-13", forHTTPHeaderField: "X-Runway-Version")

    logger.debug("Sending request to \(endpoint.absoluteString)")
    let (data, response) = try await URLSession.shared.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse else {
      logger.error("Invalid response received")
      throw RunwayMLError.invalidResponse
    }

    logger.info("Received response with status code: \(httpResponse.statusCode)")

    switch httpResponse.statusCode {
      case 200:
        do {
          let taskResponse = try JSONDecoder().decode(RunwayMLTaskResponse.self, from: data)
          logger.info("Successfully retrieved task details for task ID: \(taskResponse.id)")
          return taskResponse
        } catch {
          logger.error("Failed to decode task response: \(error.localizedDescription)")
          throw RunwayMLError.decodingFailed
        }
      case 429:
        logger.warning("Rate limit exceeded")
        throw RunwayMLError.rateLimitExceeded
      case 400:
        logger.error("Bad request")
        throw RunwayMLError.badRequest
      case 401:
        logger.error("Unauthorized access")
        throw RunwayMLError.unauthorized
      case 404:
        logger.error("Resource not found")
        throw RunwayMLError.notFound
      case 405:
        logger.error("Method not allowed")
        throw RunwayMLError.methodNotAllowed
      case 502, 503, 504:
        logger.error("Service unavailable")
        throw RunwayMLError.serviceUnavailable
      default:
        logger.error("Unexpected status code: \(httpResponse.statusCode)")
        throw RunwayMLError.invalidResponse
    }
  }

  /// Processes the task response and returns a human-readable description
  ///
  /// - Parameter task: The TaskResponse object to process
  /// - Returns: A string describing the task status and details
  public func processTaskResponse(_ task: RunwayMLTaskResponse) -> String {
    logger.info("Processing task response for task ID: \(task.id)")
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
  public func cancelOrDeleteTask(id: String) async throws {
    logger.info("Cancelling or deleting task with ID: \(id)")
    let endpoint = baseURL.appendingPathComponent("tasks/\(id)")

    var request = URLRequest(url: endpoint)
    request.httpMethod = "DELETE"
    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    request.setValue("2024-09-13", forHTTPHeaderField: "X-Runway-Version")

    logger.debug("Sending DELETE request to \(endpoint.absoluteString)")
    let (_, response) = try await URLSession.shared.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse else {
      logger.error("Invalid response received")
      throw RunwayMLError.invalidResponse
    }

    logger.info("Received response with status code: \(httpResponse.statusCode)")

    switch httpResponse.statusCode {
      case 204:
        logger.info("Task successfully canceled or deleted")
        return // Task successfully canceled or deleted
      case 429:
        logger.warning("Rate limit exceeded")
        throw RunwayMLError.rateLimitExceeded
      case 400:
        logger.error("Bad request")
        throw RunwayMLError.badRequest
      case 401:
        logger.error("Unauthorized access")
        throw RunwayMLError.unauthorized
      case 404:
        logger.error("Resource not found")
        throw RunwayMLError.notFound
      case 405:
        logger.error("Method not allowed")
        throw RunwayMLError.methodNotAllowed
      case 502, 503, 504:
        logger.error("Service unavailable")
        throw RunwayMLError.serviceUnavailable
      default:
        logger.error("Unexpected status code: \(httpResponse.statusCode)")
        throw RunwayMLError.invalidResponse
    }
  }

  /// Generates a video based on a prompt and an image.
  ///
  /// This function initiates a video generation task using the provided prompt and image. It then polls the task status
  /// until the video is successfully generated or an error occurs.
  ///
  /// - Parameters:
  ///   - prompt: A string describing the desired video content.
  ///   - image: A `ShipinImage` object representing the input image.
  ///   - duration: The desired duration of the video. Defaults to `.short`.
  ///   - aspectRatio: The aspect ratio of the video. Defaults to `.widescreen`.
  ///   - watermark: A boolean indicating whether to include a watermark. Defaults to `false`.
  ///   - seed: An optional integer seed for reproducible results. Defaults to `nil`.
  ///
  /// - Returns: A `URL` pointing to the generated video.
  ///
  /// - Throws: `RunwayMLError` if there's an issue during video generation or polling.
  ///
  /// - Example:
  ///   ```swift
  ///   let runvey = ShipinKit(apiKey: "your-api-key")
  ///   let image = ShipinImage(data: imageData)
  ///   do {
  ///       let videoURL = try await runvey.generateVideo(
  ///           prompt: "A serene lake with mountains in the background",
  ///           image: image,
  ///           duration: .medium,
  ///           aspectRatio: .square
  ///       )
  ///       print("Video generated successfully: \(videoURL)")
  ///   } catch {
  ///       print("Error generating video: \(error)")
  ///   }
  ///   ```
  public func generateVideo(prompt: String, image: ShipinImage, duration: RunwayMLVideoDuration = .short, aspectRatio: RunwayMLAspectRatio = .widescreen, watermark: Bool = false, seed: Int? = nil) async throws -> URL {
    logger.info("Starting video generation")

    let taskID = try await generateTask(prompt: prompt, image: image, duration: duration, aspectRatio: aspectRatio, watermark: watermark, seed: seed)

    return try await pollTaskStatus(id: taskID)
  }

  /// Generates a video based on a prompt and an image URL.
  ///
  /// This function initiates a video generation task using the provided prompt and image URL. It then polls the task status
  /// until the video is successfully generated or an error occurs.
  ///
  /// - Parameters:
  ///   - prompt: A string describing the desired video content.
  ///   - imageURL: A `URL` pointing to the input image.
  ///   - duration: The desired duration of the video. Defaults to `.short`.
  ///   - aspectRatio: The aspect ratio of the video. Defaults to `.widescreen`.
  ///   - watermark: A boolean indicating whether to include a watermark. Defaults to `false`.
  ///   - seed: An optional integer seed for reproducible results. Defaults to `nil`.
  ///
  /// - Returns: A `URL` pointing to the generated video.
  ///
  /// - Throws: `RunwayMLError` if there's an issue during video generation or polling.
  ///
  /// - Example:
  ///   ```swift
  ///   let runvey = ShipinKit(apiKey: "your-api-key")
  ///   let imageURL = URL(string: "https://example.com/input-image.jpg")!
  ///   do {
  ///       let videoURL = try await runvey.generateVideo(
  ///           prompt: "A bustling cityscape transforming through seasons",
  ///           imageURL: imageURL,
  ///           duration: .long,
  ///           aspectRatio: .vertical,
  ///           watermark: true
  ///       )
  ///       print("Video generated successfully: \(videoURL)")
  ///   } catch {
  ///       print("Error generating video: \(error)")
  ///   }
  ///   ```
  public func generateVideo(prompt: String, imageURL: URL, duration: RunwayMLVideoDuration = .short, aspectRatio: RunwayMLAspectRatio = .widescreen, watermark: Bool = false, seed: Int? = nil) async throws -> URL {
    logger.info("Starting video generation")

    let taskID = try await generateTask(prompt: prompt, imageURL: imageURL, duration: duration, aspectRatio: aspectRatio, watermark: watermark, seed: seed)

    return try await pollTaskStatus(id: taskID)
  }

  private func pollTaskStatus(id: String) async throws -> URL {
    logger.debug("Starting to poll task status for ID: \(id)")

    while true {
      do {
        let status = try await getTaskDetails(id: id)
        logger.debug("Current status: \(status.status.rawValue)")

        switch status.status {
          case .succeeded:
            if let videoURLString = status.output?.first,
               let videoURL = URL(string: videoURLString) {
              logger.info("Video generation succeeded")
              logger.debug("Video URL: \(videoURL)")
              return videoURL
            } else {
              logger.error("Failed to get video URL from successful response")
              throw RunwayMLError.invalidResponse
            }
          case .failed:
            logger.error("Task failed")
            throw RunwayMLError.invalidResponse
          case .pending, .throttled, .running:
            logger.debug("Task is \(status.status.rawValue), waiting for 5 seconds before next poll")
            try await Task.sleep(for: .seconds(5))
        }
      } catch {
        logger.error("Error while polling: \(error.localizedDescription)")
        throw error
      }
    }
  }
}
