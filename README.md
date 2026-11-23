# Vexel iOS

A native iPhone and iPad motion-graphics editor port, built around a Swift editing core, SwiftUI workspace, Metal
rendering, and AVFoundation media pipeline.

**Current status:** project-format milestone. The repository contains a universal SwiftUI app, a testable Swift core,
a secure .knsproj importer with version 1–12 migration handling, native .vexelproj archive save/load, asset preservation,
and a GitHub Actions workflow that builds an unsigned device IPA. Timeline editing, rendering, effects, audio and
export parity remain in progress.

## Repository structure

- `App/`: SwiftUI iOS application.
- `Packages/VexelCore/`: platform-independent project and editing core.
- `.github/workflows/ios-ipa.yml`: CI tests and unsigned IPA packaging.
- `KnsprojArchiveImporter`: Kinesis project import, migration and asset extraction.
- `VexelProjectArchive`: native .vexelproj archive save/load with asset integrity checks.
- `docs/`: architecture, reverse-engineering evidence, porting roadmap, project format, testing, licensing, and build instructions.

## Build without owning a Mac

Push a commit or run **Actions → iOS Build → Run workflow**. After the workflow succeeds, download the
`Vexel-unsigned-IPA` artifact. It is an unsigned build artifact, not directly installable on a physical iPhone.
Device installation requires signing and a provisioning profile. See [docs/BUILDING.md](docs/BUILDING.md).

## Current import capability

Use the folder icon to open either a .knsproj or .vexelproj file. Kinesis imports migrate supported source versions
to the v12 document shape and retain the original source document. Use the save icon to write a native .vexelproj
archive; the share sheet can export it to Files. Both archive formats preserve referenced media and unknown document
fields. The imported project is not yet fully editable or renderable; the layer and effect engines are being ported
separately.

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
