//
//  LumaAIError.swift
//  ShipinKit
//
//  Created by Rudrank Riyam on 10/13/24.
//



/// An error type representing errors from the Luma AI client.
public enum LumaAIError: Error {
  /// An HTTP error with a status code.
  case httpError(statusCode: Int)
  /// A decoding error occurred.
  case decodingError(underlying: Error)
}
