# Vexel iOS

A native iPhone and iPad motion-graphics editor port, built around a Swift editing core, SwiftUI workspace, Metal
rendering, and AVFoundation media pipeline.

**Current status:** UI port milestone plus modular engine foundation. The repository now defines separate Swift packages for Core, Archive, Renderer, Media, Audio, Export and Plugins. The renderer has an initial validated render-graph model and native MSL implementations for copy, brightness/contrast, Gaussian blur and multi-scale glow combination. These are foundations, not a complete renderer: the Vexel project compatibility importer, secure ZIP implementation, editing command system, deterministic scene evaluator, full effect pass library, media decoding, audio mixer and export writer remain in progress.

## Repository structure

- `App/`: SwiftUI iOS application, navigation, design system, editor workspace, effect catalogue, advanced panels, and workflow dialogs.
- `Packages/VexelCore/`: platform-independent project and editing core.
- `Packages/VexelArchive/`: project archive contracts and format adapters.
- `Packages/VexelRenderer/`: Metal render graph and native shader library.
- `Packages/VexelMedia/`: AVFoundation/CoreVideo media contracts.
- `Packages/VexelAudio/`: realtime and offline audio contracts.
- `Packages/VexelExport/`: shared preview/export orchestration contracts.
- `Packages/VexelPlugins/`: plugin package and capability contracts.
- `.github/workflows/ios-ipa.yml`: CI tests and unsigned IPA packaging.
- `docs/`: architecture, reverse-engineering evidence, porting roadmap, project format, testing, licensing, and build instructions.

## Build without owning a Mac

Push a commit or run **Actions → iOS Build → Run workflow**. After the workflow succeeds, download the
`Vexel-unsigned-IPA` artifact. It is an unsigned build artifact, not directly installable on a physical iPhone.
Device installation requires signing and a provisioning profile. See [docs/BUILDING.md](docs/BUILDING.md).

## Development

Run each package's tests with:

```sh
for package in Packages/*; do [ ! -f "$package/Package.swift" ] || swift test --package-path "$package"; done
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
- [Modular engine architecture](docs/MODULAR_ENGINE_ARCHITECTURE.md)
- [Renderer and shader port specification](docs/RENDERER_SHADER_PORT.md)
- [Source attribution](NOTICE.md)

## Compatibility and licensing

Vexel uses `.vexelproj` as its native project format. Android reference project archives are accepted through a dedicated compatibility import path and are converted to the native Vexel format when saved or exported. Vexel does not export projects in the external source format.
Unknown JSON fields are retained by the initial Swift document model to avoid discarding future project data.

The Android reference UI is GPL-3.0. The UI adaptation is distributed under GPL-3.0; see [LICENSE](LICENSE) and [NOTICE.md](NOTICE.md). Review distribution obligations before shipping binaries.
