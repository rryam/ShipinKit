# ShipinKit: Swift SDK for Prototyping AI Video Generation

ShipinKit is an unofficial Swift SDK designed for quick prototyping and easy integration with video generation capabilities. The name is based on the Chinese word for video, which is 视频.

<a href="https://www.emergetools.com/app/example/ios/runveykit.RunveyKit/manual?utm_campaign=badge-data"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fwww.emergetools.com%2Fapi%2Fv2%2Fpublic_new_build%3FexampleId%3Drunveykit.RunveyKit%26platform%3Dios%26badgeOption%3Dversion_and_max_install_size%26buildType%3Dmanual&query=$.badgeMetadata&label=RunveyKit&logo=apple" /></a>

## Features

- Generate videos using text prompts and input images
- Customizable generation parameters (duration, aspect ratio, watermark, seed)
- Swift async/await support
- Error handling for common API issues
- Retrieve task details and process them into a human-readable description
- Cancel or delete a task

## Requirements

- Swift 6.0+
- iOS 16.0+, macOS 14.0+, tvOS 16.0+, watchOS 9.0+, visionOS 1.0+

## Installation

Add ShipinKit to your Swift package dependencies:

```swift
dependencies: [
    .package(url: "https://github.com/rryam/ShipinKit.git", from: "1.0.0")
]
```

## Important Note

This library is intended for quick prototyping and development purposes only. For production use, it is highly recommended to implement a more secure and controlled approach to managing API keys, such as using environment variables or a secure key management service.

## Usage

Here are examples of how to use ShipinKit to generate videos:

```swift
// Generate video from image data
let runvey = ShipinKit(apiKey: "your-api-key")
let image = UIImage(named: "input-image.jpg")!
do {
    let videoURL = try await runvey.generateVideo(
        prompt: "A serene lake with mountains in the background",
        image: image,
        duration: .medium,
        aspectRatio: .widescreen
    )
    print("Video generated successfully: \(videoURL)")
} catch {
    print("Error generating video: \(error)")
}

// Generate video from image URL
let runvey = ShipinKit(apiKey: "your-api-key")
let imageURL = URL(string: "https://example.com/input-image.jpg")!
do {
    let videoURL = try await runvey.generateVideo(
        prompt: "A bustling cityscape transforming through seasons",
        imageURL: imageURL,
        duration: .long,
        aspectRatio: .portrait,
        watermark: true
    )
    print("Video generated successfully: \(videoURL)")
} catch {
    print("Error generating video: \(error)")
}
```

Here is a basic example of how to use ShipinKit to generate a task if you prefer manual control:

```swift
import ShipinKit

do {
    let prompt = "Dynamic tracking shot: The camera glides through the iconic Shibuya Crossing in Tokyo at night, capturing the bustling intersection bathed in vibrant neon lights. Countless pedestrians cross the wide intersection as towering digital billboards illuminate the scene with colorful advertisements. The wet pavement reflects the dazzling lights, creating a cinematic urban atmosphere."
    let imageURL = URL(string: "https://images.unsplash.com/photo-1542051841857-5f90071e7989?q=80&w=3270&auto=format&fit=crop&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D")!

    let shipinKit = ShipinKit(apiKey: "YOUR_API_KEY_HERE")
    let taskID = try await shipinKit.generateTask(
        prompt: prompt,
        imageURL: imageURL,
        duration: .long, // 10 seconds
        aspectRatio: .widescreen, // 16:9 ratio
    )

    print("Image generation task started with ID: \(taskID)")
} catch {
    print("Error generating image: \(error)")
}
```

Here's an example of how to retrieve task details and process them into a human-readable description:

```swift
import ShipinKit

    do {
        let shipinKit = ShipinKit(apiKey: "YOUR_API_KEY_HERE")
        let taskId = "17f20503-6c24-4c16-946b-35dbbce2af2f"
        let taskDetails = try await shipinKit.getTaskDetails(id: taskId)
        print(taskDetails)
    } catch {
        print("Error: \(error)")
    }
```

And here's an example of how to cancel or delete a task:

```swift
import ShipinKit

    do {
        let shipinKit = ShipinKit(apiKey: "YOUR_API_KEY_HERE")
        let taskId = "17f20503-6c24-4c16-946b-35dbbce2af2f"
        try await shipinKit.cancelOrDeleteTask(id: taskId)
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

This is an unofficial library and is not affiliated with or endorsed by RunwayML, Luma Labs or Kling AI.
