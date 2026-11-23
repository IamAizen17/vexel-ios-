# Vexel iOS

A native iPhone and iPad motion-graphics editor port, built around a Swift editing core, SwiftUI workspace, Metal
rendering, and AVFoundation media pipeline.

**Current status:** UI port milestone. The repository contains the onboarding flow, project library, presets, settings, plugin manager, editor tools, source-driven 73-effect catalogue with parameter controls, nested timeline UI, properties, graph/curve, audio, captions, text-to-speech, camera, cutout, stabilization, markers and export screens in native SwiftUI. Timeline/effect presentation state is not yet connected to a canonical editing engine. The KnsProject v12 importer, project archive, scene evaluator, Metal renderer, media/audio engine and export implementation remain pending.

## Repository structure

- `App/`: SwiftUI iOS application, navigation, design system, editor workspace, effect catalogue, advanced panels, and workflow dialogs.
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
- [Reference UI port comparison](docs/UI_PORT.md)
- [Source engine audit](docs/ENGINE_SOURCE_AUDIT.md)
- [Engine field matrix and compatibility contract](docs/ENGINE_FIELD_MATRIX.md)
- [Native iOS engine port plan](docs/ENGINE_PORT_PLAN.md)
- [Source attribution](NOTICE.md)

## Compatibility and licensing

The Android reference format is `.knsproj` version 12. Vexel's own `.vexelproj` format is versioned separately.
Unknown JSON fields are retained by the initial Swift document model to avoid discarding future project data.

The Android reference UI is GPL-3.0. The UI adaptation is distributed under GPL-3.0; see [LICENSE](LICENSE) and [NOTICE.md](NOTICE.md). Review distribution obligations before shipping binaries.
