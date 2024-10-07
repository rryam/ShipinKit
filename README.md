# RunveyKit: Unofficial Swift Library for RunwayML

RunveyKit is an unofficial Swift SDK for the RunwayML REST API, designed for quick prototyping and easy integration with RunwayML's image generation capabilities.

## Features

- Generate images using text prompts and input images
- Customizable generation parameters (duration, aspect ratio, watermark, seed)
- Swift async/await support
- Error handling for common API issues
- Retrieve task details and process them into a human-readable description
- Cancel or delete a task

## Requirements

- Swift 6.0+
- iOS 13.0+, macOS 13.0+, tvOS 13.0+, watchOS 8.0+, visionOS 1.0+

## Installation

Add RunveyKit to your Swift package dependencies:

```swift
dependencies: [
    .package(url: "https://github.com/rryam/RunveyKit.git", from: "0.1.0")
]
```

## Configuration

Before using the library, make sure to set your RunwayML API key:

```swift
RunwayML.apiKey = "YOUR_API_KEY_HERE"
```

**Important Note:** This library is intended for quick prototyping and development purposes only. For production use, it is highly recommended to implement a more secure and controlled approach to managing API keys, such as using environment variables or a secure key management service.

## Usage

Here is a basic example of how to use RunveyKit to generate an image:

```swift
import RunwayKit

    do {
        let prompt = "Dynamic tracking shot: The camera glides through the iconic Shibuya Crossing in Tokyo at night, capturing the bustling intersection bathed in vibrant neon lights. Countless pedestrians cross the wide intersection as towering digital billboards illuminate the scene with colorful advertisements. The wet pavement reflects the dazzling lights, creating a cinematic urban atmosphere."
        let imageURL = URL(string: "https://images.unsplash.com/photo-1542051841857-5f90071e7989?q=80&w=3270&auto=format&fit=crop&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D")!

        let taskID = try await RunwayML.generateImage(
            prompt: prompt,
            imageURL: imageURL,
            duration: .long, // 10 seconds
            aspectRatio: .widescreen, // 16:9 ratio
            watermark: false,
            seed: 42
        )

        print("Image generation task started with ID: \(taskID)")
    } catch {
        print("Error generating image: \(error)")
    }
```

And here's an example of how to retrieve task details and process them into a human-readable description:

```swift
import RunwayKit

    do {
        let taskId = "17f20503-6c24-4c16-946b-35dbbce2af2f"
        let taskDetails = try await RunwayML.getTaskDetails(id: taskId)
        let description = RunwayML.processTaskResponse(taskDetails)
        print(description)
    } catch {
        print("Error: \(error)")
    }
```

And here's an example of how to cancel or delete a task:

```swift
import RunwayKit

    do {
        let taskId = "17f20503-6c24-4c16-946b-35dbbce2af2f"
        try await RunwayML.cancelOrDeleteTask(id: taskId)
        print("Task \(taskId) has been successfully canceled or deleted.")
    } catch {
        print("Error canceling or deleting task: \(error)")
    }
```

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Disclaimer

This is an unofficial library and is not affiliated with or endorsed by RunwayML.
