//
//  ShipinKitTests.swift
//  ShipinKit
//
//  Created by Rudrank Riyam on 10/7/24.
//

import XCTest
@testable import ShipinKit

final class ShipinKitTests: XCTestCase {
  var shipinKit: RunwayML!

  override func setUp() {
    super.setUp()
    shipinKit = RunwayML(apiKey: "KEY_HERE")
  }

  func testShipinKitInitialization() {
    XCTAssertNotNil(shipinKit)
  }

  func testGenerateImage() async throws {
    let prompt = "Dynamic tracking shot: The camera glides through the iconic Shibuya Crossing in Tokyo at night, capturing the bustling intersection bathed in vibrant neon lights. Countless pedestrians cross the wide intersection as towering digital billboards illuminate the scene with colorful advertisements. The wet pavement reflects the dazzling lights, creating a cinematic urban atmosphere."
    let imageURL = URL(string: "https://images.unsplash.com/photo-1501560379-05951a742668?q=80&w=3270&auto=format&fit=crop&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D")!

    do {
      let taskID = try await shipinKit.generateTask(prompt: prompt, imageURL: imageURL)
      debugPrint(taskID)
      XCTAssertFalse(taskID.isEmpty)
    } catch {
      XCTFail("Generate image failed with error: \(error)")
    }
  }

  func testGetTaskDetails() async throws {
    let taskID = "299d8c18-30aa-47a0-b0d4-7e9ed72db017"

    do {
      let taskDetails = try await shipinKit.getTaskDetails(id: taskID)
      debugPrint(taskDetails)
      XCTAssertEqual(taskDetails.id, taskID)
    } catch {
      XCTFail("Get task details failed with error: \(error)")
    }
  }

  func testCancelOrDeleteTask() async throws {
    let taskID = "test_task_id"

    do {
      try await shipinKit.cancelOrDeleteTask(id: taskID)
      // If we reach here, the test passes
    } catch {
      XCTFail("Cancel or delete task failed with error: \(error)")
    }
  }
}
