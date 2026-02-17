# Contributing to Barcodes

Thanks for your interest in contributing! This guide will help you get started.

## Reporting Bugs & Suggesting Features

Please use the [issue templates](https://github.com/alexislours/barcode-stash/issues/new/choose) to report bugs or request features. Include as much detail as possible — screenshots, steps to reproduce, and device info are all helpful.

## Development Setup

- **Xcode 26.2+** (no third-party dependencies)
- **iOS 26.2+** deployment target
- A **physical device** is required for camera/barcode scanning — the simulator cannot use `AVCaptureSession`

Clone the repo and open `barcodes.xcodeproj` in Xcode. Build and run on a simulator or device.

To build from the command line:

```bash
xcodebuild -project barcodes.xcodeproj -scheme barcodes \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

## Code Style Notes

This project uses a few patterns worth knowing before contributing:

- **Default MainActor isolation.** The build setting `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` means all types are MainActor-isolated by default. Use `nonisolated` explicitly when you need to opt out (e.g., delegate callbacks that arrive on arbitrary threads).

- **Delegate callback pattern.** Delegate methods that arrive off the main actor must be marked `nonisolated` and dispatch back via `Task { @MainActor in ... }`. See `LocationManager` for the canonical example.

- **SwiftData predicate workaround.** `#Predicate` cannot compare `Codable` enum properties directly — it silently fails at runtime. Predicate on raw `String` fields and filter enums in memory.

## Linting & Formatting

This project uses [SwiftLint](https://github.com/realm/SwiftLint) and [SwiftFormat](https://github.com/nicklockwood/SwiftFormat). Both are installed via Homebrew:

```bash
brew install swiftlint swiftformat
```

Before submitting a PR, run:

```bash
make lint          # Check for lint violations
make format        # Auto-format code
make lint-fix      # Auto-fix lint violations
make format-check  # Dry-run format check (used in CI)
```

CI will run `make lint` and `make format-check` on every pull request.

## Pull Requests

1. Fork the repository and create a feature branch from `main`.
2. Keep PRs small and focused — one feature or fix per PR.
3. Run `make lint` and `make format` before submitting.
4. Make sure the project builds without warnings before submitting.
5. Describe what you changed and why in the PR description.

## License

This project is licensed under the [GNU General Public License v3.0](LICENSE). By submitting a pull request, you agree that your contributions will be licensed under the same license.

## Code of Conduct

Please read and follow our [Code of Conduct](CODE_OF_CONDUCT.md). We are committed to providing a welcoming and inclusive experience for everyone.
