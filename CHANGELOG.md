# Changelog

All notable changes to ShipinKit are documented here. The project follows
[Semantic Versioning](https://semver.org/).

## 2.0.0 - 2026-07-31

### Security

- Removed credential and request/response logging from both providers.
- Removed the credential-bearing environment variable from the shared example scheme.
- Added lazily resolved, always-redacted credentials and finite request timeouts.
- Reject provider identifiers that could escape their URL path segment.

### Changed

- Renamed the package product and module from `RunveyKit` to `ShipinKit`.
- Replaced public `Any` results and stringly typed provider parameters with typed contracts.
- Updated Runway to API version `2024-11-06`, Gen-4.5, and Gen-4 Turbo.
- Updated Luma video generation to Ray 2, Ray 2 Flash, the current video endpoint,
  typed concepts, optional response fields, and forward-compatible duration/resolution values.
- Replaced live placeholder tests with deterministic fixture transports.
- Made `ShipinKit` a dynamic library so the existing XCFramework workflow consumes the
  package without rewriting its manifest.

### Added

- `ShipinCredential`, `ShipinTransport`, `ShipinHTTPResponse`, and `ShipinError`.
- Typed Runway task states and Luma generation states.
- Explicit polling, failure, cancellation, timeout, and output receipts.
- A typed `ShipinClient` facade for applications that select a provider at runtime.

### Migration

Version 2.0 is intentionally source-breaking. See the README's
[`Migrating to 2.0`](README.md#migrating-to-20) section for replacements.

## 1.0.0 - 2024-10-09

- Initial stable release under the `RunveyKit` product and module name.
