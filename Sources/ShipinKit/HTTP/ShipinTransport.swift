import Foundation

/// The response returned by a ``ShipinTransport``.
public struct ShipinHTTPResponse: Sendable, Equatable {
  public let data: Data
  public let statusCode: Int

  public init(data: Data = Data(), statusCode: Int) {
    self.data = data
    self.statusCode = statusCode
  }
}

/// An injectable boundary for all network I/O performed by ShipinKit.
public protocol ShipinTransport: Sendable {
  func send(_ request: URLRequest) async throws -> ShipinHTTPResponse
}

/// The production transport backed by `URLSession`.
public struct URLSessionShipinTransport: ShipinTransport {
  private let session: URLSession

  public init(session: URLSession = .shared) {
    self.session = session
  }

  public func send(_ request: URLRequest) async throws -> ShipinHTTPResponse {
    do {
      let (data, response) = try await session.data(for: request)
      guard let response = response as? HTTPURLResponse else {
        throw ShipinError.invalidHTTPResponse
      }
      return ShipinHTTPResponse(data: data, statusCode: response.statusCode)
    } catch is CancellationError {
      throw CancellationError()
    } catch let error as URLError where error.code == .cancelled && Task.isCancelled {
      throw CancellationError()
    } catch let error as ShipinError {
      throw error
    } catch {
      throw ShipinError.transportFailure(String(describing: error))
    }
  }
}
