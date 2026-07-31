# Security Policy

## Supported versions

Only the latest ShipinKit 2.x release receives security fixes. The 1.x line is no
longer supported and should not be used for new integrations.

## Reporting a vulnerability

Please do not disclose a suspected vulnerability in a public issue. Email
[contact@rudrank.com](mailto:contact@rudrank.com) with:

- the affected ShipinKit version;
- a minimal reproduction or request/response shape with all credentials redacted;
- the impact and any known mitigations.

Do not include usable API keys, bearer tokens, signed URLs, or private provider
responses. You should receive an acknowledgement within seven days.

## Credential guidance

ShipinKit does not persist or log provider credentials. Applications remain
responsible for resolving credentials from a secure app-owned service, rotating
compromised keys, and preventing secrets from entering source control, shared
Xcode schemes, logs, fixtures, crash reports, and analytics.

Credentials embedded in a distributed client cannot be kept fully secret. Use a
narrow authenticated server endpoint for production applications.
