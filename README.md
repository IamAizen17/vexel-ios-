# Vexel for iOS

Native iPhone and iPad motion-graphics editor, targeting full functional parity with the Kinesis Editor reference while introducing an original Vexel interface.

## Project status

**Stage:** Architecture and source-reconstruction planning.

This repository is the destination for the iOS port. The Android reference is [IamAizen17/vexel-editor](https://github.com/IamAizen17/vexel-editor). This repository is not yet a functioning iOS application.

## Product decisions

- iPhone and iPad from the beginning.
- Full feature parity is the target.
- Original Vexel interface, designed for touch and adaptive iPad workspaces.
- Native Apple technologies: SwiftUI, Metal, AVFoundation and AVAudioEngine.
- Native project extension: .vexelproj.
- Import compatibility for existing .knsproj projects.

## Engineering approach

Reconstruct project format, editing semantics, scene evaluation, renderer, effects and media pipeline from source and tests. Record evidence and unknowns. Implement each subsystem natively and validate it against compatibility fixtures and deterministic golden tests.

The reference project is GPL-3.0. Review [Licensing and Attribution](docs/LICENSING_AND_ATTRIBUTION.md) before distributing derivative code or binaries.

## Documentation

- [Architecture](docs/ARCHITECTURE.md)
- [Source reconstruction plan](docs/REVERSE_ENGINEERING_PLAN.md)
- [Full parity roadmap](docs/PORTING_ROADMAP.md)
- [Project format](docs/PROJECT_FORMAT.md)
- [Testing strategy](docs/TESTING.md)
- [Licensing and attribution](docs/LICENSING_AND_ATTRIBUTION.md)

## Current limitations

No Swift application target, Metal renderer, media pipeline or project importer has been implemented yet. The source audit has begun, but the complete reference repository and runtime behavior have not yet been exhaustively investigated. Simulator builds, device tests and export tests are not yet available.
