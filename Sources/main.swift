import Foundation
import UIKit

// MARK: - RunwayML

/// A struct that encapsulates the RunwayML API functionality
public struct RunwayML {
    // MARK: - Constants
    
    public static let apiKey = "YOUR_API_KEY_HERE"
    public static let baseURL = URL(string: "https://api.runwayml.com/v1")!
    
    // MARK: - Enums
    
    /// Custom error types for RunwayML operations
    public enum RunwayMLError: Error {
        case invalidURL
        case requestFailed(Error)
        case invalidResponse
        case decodingFailed
        case rateLimitExceeded
        case invalidSeed
        case imageTooLarge
    }
    
    /// Duration options for image generation
    public enum Duration: Int {
        case short = 5
        case long = 10
    }
    
    /// Aspect ratio options for image generation
    public enum AspectRatio: String {
        case widescreen = "16:9"
        case portrait = "9:16"
    }
    
    // MARK: - Models
    
    /// Response model for image generation
    public struct GenerateResponse: Codable {
        let id: String
    }
    
    /// Response model for task details
    public struct TaskResponse: Codable {
        let id: String
        let status: TaskStatus
        let createdAt: Date
        let progress: Double?
        let output: [String]?
        let failure: String?
        let failureCode: String?
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
    public static func generateImage(
        prompt: String,
        imageURL: URL,
        duration: Duration = .short,
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
        image: UIImage,
        duration: Duration = .short,
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
    public static func imageToBase64String(_ image: UIImage) throws -> String {
        guard let imageData = image.jpegData(compressionQuality: 1) else {
            throw RunwayMLError.requestFailed(NSError(domain: "Image conversion failed", code: 0, userInfo: nil))
        }
        
        let base64String = imageData.base64EncodedString()
        
        // Check if the base64 string is under the 3MB limit
        let base64Data = Data(base64String)
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
        case 404:
            print("Task \(id) not found. It may have already been deleted or aborted.")
        case 429:
            throw RunwayMLError.rateLimitExceeded
        default:
            throw RunwayMLError.invalidResponse
        }
    }
}
