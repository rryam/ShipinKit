//
//  RunwayMLError.swift
//  ShipinKit
//
//  Created by Rudrank Riyam on 10/9/24.
//

import Foundation

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
