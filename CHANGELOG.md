# Changelog

All notable changes to this project are documented here.

## [0.1.1] - 2026-08-02

- Rewrote the English and Chinese introductions with a plain-language explanation and a concrete YouTube example.
- Added a bilingual beginner setup wizard with port checks and reversible Edge policy installation.
- Added a double-click Windows launcher for the beginner wizard.
- Added a practical AI-and-media routing preset so beginners do not need to identify CDN domains manually.
- Rejected protected/bulk parent-domain overlaps that would otherwise make a rule unreachable.
- Added beginner and manual installation guides.
- Added an offline integration test for the setup wizard.

## [0.1.0] - 2026-08-02

- Added JSON-driven PAC generation with fail-closed protected domains.
- Added offline PAC routing tests.
- Added reversible Microsoft Edge policy installation.
- Added an optional least-privilege Windows service for Hysteria 2.
- Added official-release download and SHA-256 verification.
- Added local health checks, CI, and a repository secret scan.
