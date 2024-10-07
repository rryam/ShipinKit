import Foundation

// MARK: - RunwayML

/// A struct that encapsulates the RunwayML API functionality
struct RunwayML {
    // MARK: - Constants
    
    static let apiKey = "YOUR_API_KEY_HERE"
    static let baseURL = URL(string: "https://api.runwayml.com/v1")!
    
    // MARK: - Enums
    
    /// Custom error types for RunwayML operations
    enum RunwayMLError: Error {
        case invalidURL
        case requestFailed(Error)
        case invalidResponse
        case decodingFailed
        case rateLimitExceeded
        case invalidSeed
    }
    
    /// Duration options for image generation
    enum Duration: Int {
        case short = 5
        case long = 10
    }
    
    /// Aspect ratio options for image generation
    enum AspectRatio: String {
        case widescreen = "16:9"
        case portrait = "9:16"
    }
    
    // MARK: - Models
    
    /// Response model for image generation
    struct GenerateResponse: Codable {
        let id: String
    }
    
    /// Response model for task details
    struct TaskResponse: Codable {
        let id: String
        let status: TaskStatus
        let createdAt: Date
        let progress: Double?
        let output: [String]?
        let failure: String?
        let failureCode: String?
    }

    /// Task status enum
    enum TaskStatus: String, Codable {
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
    static func generateImage(
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
    
    /// Gets details about a task
    ///
    /// - Parameter id: The ID of the task to retrieve
    /// - Returns: A TaskResponse object containing task details
    /// - Throws: RunwayMLError
    static func getTaskDetails(id: String) async throws -> TaskResponse {
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
    static private func processTaskResponse(_ task: TaskResponse) -> String {
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
    static func cancelOrDeleteTask(id: String) async throws {
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
