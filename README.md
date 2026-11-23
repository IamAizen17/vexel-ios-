# Vexel iOS

A native iPhone and iPad motion-graphics editor port, built around a Swift editing core, SwiftUI workspace, Metal
rendering, and AVFoundation media pipeline.

**Current status:** foundation milestone. The repository now contains a Swift package for loss-preserving project
documents, an initial universal SwiftUI workspace, and a GitHub Actions workflow that tests the core and builds an
unsigned device IPA on GitHub-hosted macOS runners. Full editor parity is not implemented yet.

## Repository structure

- `App/`: SwiftUI iOS application.
- `Packages/VexelCore/`: platform-independent project and editing core.
- `.github/workflows/ios-ipa.yml`: CI tests and unsigned IPA packaging.
- `docs/`: architecture, reverse-engineering evidence, porting roadmap, project format, testing, licensing, and build instructions.

## Build without owning a Mac

Push a commit or run **Actions → iOS Build → Run workflow**. After the workflow succeeds, download the
`Vexel-unsigned-IPA` artifact. It is an unsigned build artifact, not directly installable on a physical iPhone.
Device installation requires signing and a provisioning profile. See [docs/BUILDING.md](docs/BUILDING.md).

## Development

Run core tests with:

```sh
swift test --package-path Packages/VexelCore
```

Generate the Xcode project with XcodeGen:

```sh
xcodegen generate
```

## Engineering references

- [Architecture](docs/ARCHITECTURE.md)
- [Reverse-engineering plan and evidence](docs/REVERSE_ENGINEERING_PLAN.md)
- [Porting roadmap](docs/PORTING_ROADMAP.md)
- [Vexel project format](docs/PROJECT_FORMAT.md)
- [Testing strategy](docs/TESTING.md)
- [Licensing and attribution](docs/LICENSING_AND_ATTRIBUTION.md)
- [Build and IPA workflow](docs/BUILDING.md)

## Compatibility and licensing

The Android reference format is `.knsproj` version 12. Vexel's own `.vexelproj` format is versioned separately.
Unknown JSON fields are retained by the initial Swift document model to avoid discarding future project data.

The Android reference repository declares GPL-3.0. Porting or adapting covered implementation code requires a
careful GPL compliance and distribution review before shipping binaries. See
[docs/LICENSING_AND_ATTRIBUTION.md](docs/LICENSING_AND_ATTRIBUTION.md).
