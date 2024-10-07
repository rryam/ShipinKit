//
//  ContentView.swift
//  Runvey
//
//  Created by Rudrank Riyam on 10/7/24.
//

import SwiftUI
import AVKit
import PhotosUI
import RunveyKit

struct ContentView: View {
  @State private var selectedImage: UIImage?
  @State private var generatedVideoURL: URL?
  @State private var isLoading = false
  @State private var errorMessage: String?
  @State private var imageSelection: PhotosPickerItem?

  var body: some View {
    NavigationStack {
      VStack {
        if let selectedImage = selectedImage {
          Image(uiImage: selectedImage)
            .resizable()
            .scaledToFit()
            .cornerRadius(16)
        } else {
          AsyncImage(url: URL(string: "https://images.unsplash.com/photo-1542051841857-5f90071e7989?q=80&w=3270&auto=format&fit=crop&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wAWdlfHx8fGVufDB8fHx8fA%3D%3D")) { phase in
            if let image = phase.image {
              image
                .resizable()
                .scaledToFit()
                .cornerRadius(16)
            } else if phase.error != nil {
              Image(systemName: "exclamationmark.triangle")
                .resizable()
                .scaledToFit()
                .foregroundColor(.red)
            } else {
              ProgressView()
            }
          }
        }

        PhotosPicker(selection: $imageSelection, matching: .images) {
          Text("Select Image")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .onChange(of: imageSelection) { _, newValue in
          Task {
            if let data = try? await newValue?.loadTransferable(type: Data.self) {
              if let uiImage = UIImage(data: data) {
                await MainActor.run {
                  selectedImage = uiImage
                }
              }
            }
          }
        }

        Button(action: {
          Task {
            await generateVideo()
          }
        }) {
          Text("Generate Video")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)

        if isLoading {
          ProgressView()
            .progressViewStyle(CircularProgressViewStyle())
        } else if let videoURL = generatedVideoURL {
          VideoPlayer(player: AVPlayer(url: videoURL))
            .frame(height: 300)
            .cornerRadius(10)
        }

        if let errorMessage = errorMessage {
          Text(errorMessage)
            .foregroundColor(.red)
        }
      }
      .padding()
      .navigationTitle("RunveyKit Example")
    }
  }

  private func generateVideo() async {
    await MainActor.run {
      isLoading = true
      errorMessage = nil
    }

    print("DEBUG: Starting video generation")

    let promptText = "Dynamic tracking shot: The camera glides through the iconic Shibuya Crossing in Tokyo at night, capturing the bustling intersection bathed in vibrant neon lights. Countless pedestrians cross the wide intersection as towering digital billboards illuminate the scene with colorful advertisements. The wet pavement reflects the dazzling lights, creating a cinematic urban atmosphere."

    do {
      guard let apiKey = ProcessInfo.processInfo.environment["RUNWAYML_API_KEY"] else {
        debugPrint("Warning: RUNWAYML_API_KEY not found in environment variables")
        self.errorMessage = "Error: RUNWAYML_API_KEY not found in environment variables"
        self.isLoading = false
        return
      }

      let runveyKit = RunveyKit(apiKey: apiKey)
      let taskID: String
      
      if let selectedImage = selectedImage {
        taskID = try await runveyKit.generateImage(prompt: promptText, image: selectedImage)
      } else {
        let imageURL = "https://images.unsplash.com/photo-1542051841857-5f90071e7989?q=80&w=3270&auto=format&fit=crop&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wAWdlfHx8fGVufDB8fHx8fA%3D%3D"
        taskID = try await runveyKit.generateImage(prompt: promptText, imageURL: URL(string: imageURL)!)
      }

      debugPrint("DEBUG: Successfully created task, ID: \(taskID)")

      try await pollTaskStatus(id: taskID)
    } catch {
      await MainActor.run {
        self.errorMessage = "Error: \(error.localizedDescription)"
        self.isLoading = false
      }
      debugPrint("DEBUG: Error occurred: \(error.localizedDescription)")
    }
  }

  private func pollTaskStatus(id: String) async throws {
    debugPrint("DEBUG: Starting to poll task status for ID: \(id)")

    while true {
      do {
        guard let apiKey = ProcessInfo.processInfo.environment["RUNWAYML_API_KEY"] else {
          debugPrint("Warning: RUNWAYML_API_KEY not found in environment variables")
          return
        }

        let runveyKit = RunveyKit(apiKey: apiKey)
        let status = try await runveyKit.getTaskDetails(id: id)
        debugPrint("DEBUG: Current status: \(status.status)")

        switch status.status {
          case .succeeded:
            if let videoURLString = status.output?.first,
               let videoURL = URL(string: videoURLString) {
              debugPrint("DEBUG: Video generation succeeded")
              debugPrint("DEBUG: Video URL: \(videoURL)")
              await MainActor.run {
                self.generatedVideoURL = videoURL
                self.isLoading = false
              }
              return
            } else {
              debugPrint("DEBUG: Failed to get video URL from successful response")
              throw NSError(domain: "VideoURLError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to get video URL"])
            }
          case .failed:
            debugPrint("DEBUG: Task failed")
            throw NSError(domain: "TaskFailedError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Task failed"])
          case .pending:
            debugPrint("DEBUG: Task still processing, waiting for 5 seconds before next poll")
            try await Task.sleep(for: .seconds(5))
          case .throttled:
            debugPrint("DEBUG: Task is throttled, waiting for 10 seconds before next poll")
            try await Task.sleep(for: .seconds(10))
          case .running:
            debugPrint("DEBUG: Task is running, waiting for 5 seconds before next poll")
            try await Task.sleep(for: .seconds(5))
        }
      } catch {
        debugPrint("DEBUG: Error while polling: \(error.localizedDescription)")
        throw error
      }
    }
  }
}

#Preview {
  ContentView()
}
