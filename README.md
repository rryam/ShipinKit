# ShipinKit

ShipinKit is an unofficial Swift SDK for prototyping typed video-generation flows with the Runway and Luma APIs.

## What 2.0 provides

- Typed, provider-specific requests and responses; no public `Any` return values
- A lazily resolved, always-redacted `ShipinCredential`
- An injectable `ShipinTransport` for deterministic tests and app-owned networking
- Runway API version `2024-11-06` with Gen-4.5 and Gen-4 Turbo contracts
- Luma Ray 2 and Ray 2 Flash video-generation contracts
- Structured task states, failure receipts, polling timeouts, and cancellation handling
- Finite per-request timeouts and path-safe provider identifiers
- Offline fixture tests that never require or call a live provider account

ShipinKit never logs credentials, authorization headers, prompt bodies, or provider responses.

## Requirements

- Swift 6.0+
- iOS 16+, macOS 14+, tvOS 16+, watchOS 9+, or visionOS 1+

## Installation

```swift
dependencies: [
  .package(url: "https://github.com/rryam/ShipinKit.git", from: "2.0.0")
]
```

Then add `ShipinKit` to your target dependencies.

## Credential safety

Do not commit API keys or put them in a shared Xcode scheme. Resolve them from an app-owned secrets service instead:

```swift
let credential = ShipinCredential {
  try await secrets.runwayAPIKey()
}
```

The closure is called at request time, so an application can rotate a credential without recreating its client. `String(describing:)` and `String(reflecting:)` always produce `<redacted>`.

An API key embedded in a distributed client app cannot be kept fully secret. For production apps, keep provider credentials on a server you control and expose a narrow authenticated endpoint to the app. Direct provider access is best limited to local tools and prototypes.

## Runway

Create a typed request, start it, and wait for the complete task receipt:

```swift
import ShipinKit

let image = try RunwayMLImageSource(
  url: URL(string: "https://example.com/input.jpg")!
)
let request = try RunwayMLImageToVideoRequest(
  model: .gen4Turbo,
  promptImage: image,
  promptText: "A slow camera push through morning fog",
  duration: .fiveSeconds,
  ratio: .landscape
)

let runway = RunwayML(credential: credential)
let result = try await runway.generateVideo(request)

switch result.task.state {
  case .succeeded(let output):
    // Store provider output promptly; provider URLs are temporary.
    use(output)
  default:
    break
}
```

For manual task control:

```swift
let created = try await runway.createImageToVideoTask(request)
let latest = try await runway.task(id: created.id)
try await runway.cancelOrDeleteTask(id: created.id)
```

The request type deliberately supports the shared Gen-4.5 and Gen-4 Turbo image-to-video fields. Other Runway models have different parameter contracts and are not represented as if they were interchangeable.

## Luma

```swift
import ShipinKit

let credential = ShipinCredential {
  try await secrets.lumaAPIKey()
}
let request = try LumaAIGenerationRequest(
  prompt: "A paper boat moving across a calm pond",
  model: .ray2,
  resolution: .p720,
  duration: .fiveSeconds,
  aspectRatio: .landscape
)

let luma = LumaAI(credential: credential)
let result = try await luma.generateVideo(request)
use(result.videoURL)
```

Image-to-video uses typed keyframes:

```swift
let keyframes = try LumaAIKeyframes(
  frame0: .image(URL(string: "https://example.com/start.jpg")!)
)
let request = try LumaAIGenerationRequest(
  prompt: "A tiger walks forward through falling snow",
  keyframes: keyframes
)
```

Current Luma camera concepts are typed in requests and discoverable from the provider:

```swift
let concept = try LumaAIConcept(key: "dolly_zoom")
let request = try LumaAIGenerationRequest(
  prompt: "A car on a mountain road",
  concepts: [concept]
)
let availableConcepts = try await luma.listConcepts()
```

Known resolution and duration cases have named values. Their `.custom(...)` cases preserve newer provider values without requiring a ShipinKit release first.

## Runtime provider selection

If the application chooses a provider dynamically, `ShipinClient` returns a typed enum:

```swift
let client = ShipinClient(
  service: .runwayML(credential: credential)
)

switch try await client.generate(.runwayML(request)) {
  case .runwayML(let task):
    use(task.id)
  case .lumaAI:
    break
}
```

## Injectable transport

All clients accept any `ShipinTransport`. Tests can return fixture data and inspect the generated `URLRequest` without making a network call:

```swift
struct FixtureTransport: ShipinTransport {
  let response: ShipinHTTPResponse

  func send(_ request: URLRequest) async throws -> ShipinHTTPResponse {
    response
  }
}
```

Each client also accepts a `requestTimeout` (60 seconds by default). Polling has a separate overall `timeout`, so one stalled request and one long-running generation have independent limits.

## Migrating to 2.0

- Import and link the `ShipinKit` product. The published `1.0.0` product was named `RunveyKit`.
- Replace the old multi-parameter `generate(...) -> Any` call with a `LumaAIGenerationRequest` or `RunwayMLImageToVideoRequest`.
- Replace `gen3a_turbo`, `16:9`/`9:16` Runway values, and the old version header with the typed current model, resolution, and duration values.
- Remove the obsolete Runway `watermark` parameter; it is not part of the current image-to-video contract.
- Handle `ShipinError` for validation, transport, HTTP, terminal generation, and timeout failures.
- Replace live placeholder tests with an injected `ShipinTransport` and fixture responses.

Provider contracts are based on the official [Runway API reference](https://docs.dev.runwayml.com/api/), [Runway model catalog](https://docs.dev.runwayml.com/guides/models/), and [Luma video-generation documentation](https://docs.lumalabs.ai/docs/video-generation).

## License

ShipinKit is available under the MIT license. It is not affiliated with or endorsed by Runway or Luma AI.
