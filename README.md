# Vexel iOS

A native iPhone and iPad motion-graphics editor port, built around a Swift editing core, SwiftUI workspace, Metal
rendering, and AVFoundation media pipeline.

**Current status:** project-import milestone. The repository contains a universal SwiftUI app, a testable Swift core,
a secure .knsproj ZIP importer with version 1–12 migration handling, and a GitHub Actions workflow that builds an
unsigned device IPA. Timeline editing, rendering, effects, audio and export parity remain in progress.

## Repository structure

- `App/`: SwiftUI iOS application.
- `Packages/VexelCore/`: platform-independent project and editing core.
- `.github/workflows/ios-ipa.yml`: CI tests and unsigned IPA packaging.
- `KnsprojArchiveImporter`: Kinesis project import, migration and asset extraction.
- `docs/`: architecture, reverse-engineering evidence, porting roadmap, project format, testing, licensing, and build instructions.

## Build without owning a Mac

Push a commit or run **Actions → iOS Build → Run workflow**. After the workflow succeeds, download the
`Vexel-unsigned-IPA` artifact. It is an unsigned build artifact, not directly installable on a physical iPhone.
Device installation requires signing and a provisioning profile. See [docs/BUILDING.md](docs/BUILDING.md).

## Current import capability

Use the folder icon in the workspace to select a .knsproj file. Vexel extracts its media into Application Support,
migrates supported source versions to the v12 document shape, and retains the original source document in the
compatibility metadata. The imported project is not yet fully editable or renderable; the layer and effect engines
are being ported separately.

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
