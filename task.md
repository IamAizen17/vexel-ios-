# Vexel iOS port status

Last reviewed: 2026-11-24  
Reference repository: https://github.com/IamAizen17/vexel-editor  
Reference revision audited: 0fe341060cec9710df90bc1ba7fda85006c188d8  
iOS implementation branch: feat/modular-engine-architecture  
Related pull request: https://github.com/IamAizen17/vexel-ios-/pull/2

## Native Vexel identity

- Product, app target, display name, and bundle identifier use Vexel.
- Native project extension: `.vexelproj`.
- Native archive document: `vexel.json`.
- Native format identifier: `vexelproj`, version 1.
- Registered document type: `com.ragestudios.vexel.project`.
- Native MIME type: `application/vnd.vexel.project+zip`.
- The old Android document identifier and `project.json` archive entry are recognized only by `VexelProjectImporter`. VexelCore, persistence, and export use only the native Vexel format.


This file is the implementation handoff and active engineering backlog. “Implemented” means code exists in this branch; it does not imply complete Android parity, successful compilation of the latest commits, or device validation.

## Current implementation status

### Application and interface

- Universal SwiftUI application structure intended for iPhone and iPad.
- Four-page onboarding flow with skip, language preference, and appearance preference controls.
- Project home with Projects, Presets, and Settings destinations.
- Composition creation UI and editor workspace.
- AMOLED graphite interface with teal/cyan accents and a light appearance palette.
- Reusable material-backed panels, gradient edge treatments, rounded controls, and press feedback.
- Spring-based navigation transitions, with Reduce Motion-aware transition and press behavior.
- Timeline UI with track rows, nested group display, zoom, ruler, playhead, marker affordances, clip move/trim gestures, visibility/lock controls, and keyframe markers.
- Layer and shape tool panels, text-layer creation UI, effect browser/detail sheet, property panel, graph/curve surfaces, composition settings, and export surface.
- Saved easing preset storage with a limit of 24 entries.
- Bundled source effect catalogue: 73 effect IDs across 13 categories.

### Editing operations connected to workspace state

- Add a visual layer, text layer, and 2D shape layer.
- Duplicate and delete selected top-level layers.
- Group the selected top-level layer with its adjacent sibling.
- Split a selected top-level layer at the playhead.
- Add a keyframe timestamp to the selected track at the current frame.
- Select a layer and toggle visibility or lock state.
- Add and remove effect IDs from a selected layer's effect stack.
- Undo and redo using in-memory workspace snapshots.
- Advance the playhead during playback and stop or loop at composition duration.

These are initial workspace operations. They are not yet backed by a complete canonical editing engine. Source-compatible duplicate/split helpers and core tests now exist in VexelCore, but the SwiftUI workspace operations are not yet routed through those helpers. Keyframe data in the workspace still uses timestamps rather than editable animated property values, and nested-track selection/editing remains incomplete.

### Project data, persistence, and archive groundwork

- Native Vexel project extension `.vexelproj`, archive entry `vexel.json`, and native format identifier `vexelproj` v1.
- Registered Apple document type identifier: `com.ragestudios.vexel.project`. App bundle identifier remains `com.iamAizen17.vexel`.
- `VexelProjectItem` and timeline tracks are Codable; project metadata and workspace state are persisted under Application Support.
- `ProjectDocument` remains the generic JSON-backed native envelope. An additive `VexelNativeProject` typed schema now models the root, composition, assets, markers, all Android layer discriminators, transforms, animation tracks, keyframes, easing, loop modes, effects and recursive groups. The app bridge has not yet migrated to this typed schema.
- `VexelProjectImporter` is the isolated Android compatibility boundary. It migrates the legacy v1-v12 envelope to native Vexel.
- Android source audit is documented in `docs/ANDROID_V12_COMPATIBILITY.md`, based on Kotlin `Project.kt`, `Layer.kt`, `Content.kt`, `Animatable.kt`, `Easing.kt`, `Serializers.kt`, `KnsprojJson.kt`, `KnsprojArchive.kt`, and `ProjectValidator.kt`.
- Added the Android repository's Kotlin-generated `tools/tests/fixtures/full-kotlin.json` as `android-v12-kotlin-reference.json`; importer tests assert root migration and representative nested animation/effect/transition data.
- The editor bridge now maps non-UUID source layer IDs deterministically to UUID v5 identities. Existing UUID-shaped source IDs remain unchanged; the original source ID is retained for serialization.
- The bridge retains fractional Android Double FPS while the current editor UI exposes integer FPS, unless the user changes the rounded FPS value.
- Recursive unknown layer fields are retained through the JSON document bridge, including group descendants, but the editor only understands a subset of the source layer/content/animation model.
- Audio layers retain the `audio` discriminator even if the payload is absent; the bridge supplies an empty audio object for the interim model.
- Archive code writes native `vexel.json` and referenced assets, and rejects traversal, duplicate paths, symlinks, unsupported entries, excessive entry counts, oversized entries and high compression ratios. Extraction now enforces byte budgets against actual decompressed chunks, not only ZIP metadata.
- Import uses a staging directory and restores an existing destination after a failed promotion. Failure-injection tests cover promotion rollback and invalid-import isolation.
- Archive imports expose a structured unsupported-feature report. The current UI does not yet present that report as an import review screen.
- A source-repository Android video/audio sample archive fixture includes the exact referenced MP4/M4A assets. It follows the Android writer's ZIP layout but was assembled for tests, not exported by the Android app.

P0 remains incomplete. Outstanding work includes completing dedicated Swift models for every type-specific content payload and advanced structure, wiring the typed schema into app persistence/editing, connecting compatibility reports to import UI, obtaining a direct Android-app-exported archive, comprehensive v12 semantic validation and asset-reference coverage, native schema migrations, destination rollback-failure tests, and fresh execution of the expanded test suite. Do not claim complete Android round-trip compatibility until those checks pass.

### Engine and package foundations

- Swift packages exist for VexelCore, VexelArchive, VexelRenderer, VexelShaderCompiler, VexelMedia, VexelAudio, VexelExport, and VexelPlugins.
- JSON value representation and an initial project document model with structural validation.
- Initial archive, media, audio, export, and plugin contracts.
- Initial render graph validation and Metal renderer scaffolding.
- Initial Metal shader functions for fullscreen copy, brightness/contrast, Gaussian blur, and multi-scale glow combination.
- Shader translation interfaces and tests.
- Effect registry verification and engine/shader coverage verification scripts.
- A GitHub Actions workflow exists for package checks, Xcode project generation, generic iOS archiving, and unsigned IPA artifact packaging. Do not trigger macOS Actions jobs while the account's available usage is exhausted.

## Priority implementation backlog

Work in dependency order. Keep incomplete UI actions visibly disabled rather than presenting nonfunctional controls as implemented.

### P0: Stabilize Vexel-native persistence and Android compatibility import

- [x] Audit the Android v12 models, serializers, archive writer and migration registry against source.
- [x] Add the Kotlin-generated v12 JSON fixture and an Android repository video/audio sample archive with its real referenced media payloads. The archive is assembled for tests, not exported by the Android app.
- [x] Add typed accessors for all 11 layer content variants, text/property animators, media/equalizer/cutout metadata, shape fill/stroke/path/trim, 3D materials/text, camera depth-of-field, light properties, masks, mattes, transitions, metadata, motion blur, environment and editor view. Raw JSONValue remains the lossless backing store.
- [ ] Finish typed vector coordinate tuples, gradient endpoints, cutout frame/stroke internals and effect-specific parameter schemas; wire typed accessors into canonical app editing.
- [x] Add recursive unknown-field preservation tests across nested groups, transforms, animation tracks, effects and root metadata.
- [x] Add typed discriminator and content-accessor coverage for all 11 Android layer types, plus expression-only animations, loop modes and easing tests.
- [x] Add source-compatible core duplicate/split operations and tests for nested IDs, parent/matte references, keyframe time offsets, transitions and media in-points.
- [x] Add an import compatibility report for preserved-but-unimplemented features.
- [ ] Connect the typed schema and compatibility report to the app's persistence bridge and import review UI.
- [ ] Obtain a direct Android-app-exported `.knsproj` archive and compare its archive entries, CRCs, metadata and referenced assets.
- [ ] Complete v12 semantic validation, including all nested asset references and numeric bounds.
- [x] Add actual decompressed-byte budgets, overflow checks, per-entry limits and compression-ratio checks.
- [x] Add failure-injection tests for destination promotion rollback and invalid-import isolation.
- [ ] Test destination rollback failure and archive export replacement failure paths.
- [ ] Add native Vexel schema migrations and migration tests.
- Keep project creation, editing, persistence and export native to Vexel. Android compatibility remains isolated in `VexelProjectImporter`.

### P1: Canonical editing model and command engine

- Replace view-local mutations and workspace-owned undo stacks with an actor-owned canonical project store.
- Implement typed commands with validation, deterministic state transitions, undo/redo, and command coalescing.
- Port timeline reorder, move, trim, split, duplicate, group/ungroup, parenting, multi-selection, snapping, and ripple edits.
- Implement typed property descriptors and set-value/auto-keyframe behavior.
- Port animation sampling, keyframe clipboard/navigation, cubic Bézier easing, cyclic easing, loop and ping-pong semantics.
- Implement deterministic tests for timeline operations, keyframe evaluation, and undo/redo.
- Implement a constrained deterministic expression evaluator. Do not expose unrestricted JavaScriptCore or host APIs.
- Implement deterministic scene evaluation from project plus composition time to a renderable frame scene.

### P2: Rendering and effects

- Implement the complete Metal render graph and use the same renderer for preview and export.
- Complete GLSL-to-SPIR-V-to-MSL translation with a pinned SPIRV-Cross toolchain, diagnostics, shader validation, caching, and uniform mapping.
- Port and validate all source shaders and all 73 effects, including typed parameters, defaults, ranges, backdrop requirements, and target restrictions.
- Implement masks, track mattes, transitions, blend modes, motion blur, time slices, shadows, depth of field, HDRI, 3D materials, text extrusion, and GLB model rendering.
- Load and compile bundled Metal shader resources through the renderer at runtime.
- Add GPU image regression tests and performance/memory budgets for iPhone-class hardware.

### P3: Media, audio, captions, and export

- Implement image/video/audio/model/font import and persistent asset management.
- Implement AVFoundation decoding, frame caching, proxy generation, waveform extraction, and random-access seeking.
- Implement realtime preview audio and deterministic 48 kHz stereo mixing.
- Port speech recognition/caption generation and SRT import/export.
- Implement stabilization, background removal, cutout brush, and real-camera workflows where platform APIs and licensing allow.
- Implement MP4 export through Metal and AVAssetWriter, including progress, cancellation, resumable jobs, and codec/color-space validation.
- Implement GIF, image-sequence, and other source export formats where supported.

### P4: Product and platform integration

- Complete persistent project grid operations, including true document duplication, deletion cleanup, recovery, presets, and secure import/export.
- Implement localization, font management, settings persistence, plugin installation/permissions, and third-party license browser.
- Validate iPhone compact layouts, iPad expanded layouts, rotation, multitasking, accessibility, Dynamic Type, VoiceOver, and Reduce Motion.
- Add real-device performance, memory, battery, and thermal tests.

## Known issues and limitations

- The editor's `VexelProjectItem` and timeline tracks remain an interim UI model, not the canonical VexelCore project model.
- Persistence currently saves the project index and serialized editor state. It is not a complete autosave/recovery/snapshot system, and imported media asset lifecycle/cleanup is incomplete.
- The project/document bridge is provisional. It still maps only a subset of the typed native schema into the interim UI track model. Animated property values are preserved in the document but are not editable as complete typed values in the UI.
- `VexelProjectImporter` converts the external format/version envelope and the archive reader performs structural validation. The source video/audio archive fixture is a test-assembled archive based on Android repository examples, not a direct Android app export. This does not establish full Android source schema v12 semantic compatibility.
- Archive read/write code is connected to UI flows and now has actual-byte-budget and rollback tests. It still requires a direct Android-app-exported fixture and fresh test execution before being treated as production-ready.
- Project duplication currently creates a new blank project with copied composition settings instead of cloning the full document and assets.
- Undo/redo covers current workspace snapshot operations only. Timeline gesture coalescing and all source editing commands are not represented.
- Playback advances the playhead; it does not render animated scene frames or play audio.
- Adding an effect stores its identifier only. Effect parameters are not fully serialized or rendered.
- The effect catalogue is complete at the ID/name/category level, but effect execution and full parameter binding are incomplete.
- Transform, text, mask, transition, and graph controls are not fully connected to the project model.
- Media, audio, 3D, camera, captions, elements, plugins, stabilization, cutout, and export remain incomplete or disabled. A media picker surface does not mean media is imported into the project.
- Metal renderer and shader compiler are scaffolding. Initial shader functions do not represent full source shader parity; GLSL translation is not integrated end-to-end.
- No Android APK/IPA binary or runtime instrumentation was used for this source audit. Findings are source-level only.
- Latest changes have not been compiled or tested in a fresh workflow. macOS Actions usage is currently unavailable, so do not start another macOS runner job without the user's confirmation that usage is available.
- A prior workflow passed package checks and produced an unsigned archive/IPA, but that result predates the latest project/archive integration and does not verify the current branch.
- An unsigned IPA is not installable without valid signing/provisioning or a compatible sideloading process.
- GPL-3.0 obligations and third-party/native dependency licenses must be reviewed before distribution.

## Verification record

- Previous successful workflow: run 45282736871, commit 02b83e5f40b29de404b4df91b57b033fd51a0597.
- That run predates the current project persistence, document bridge, and ZIP archive integration. It is historical evidence only.
- Latest project/archive changes were inspected through GitHub file contents; no local Swift compiler or test execution was available during this update.
- No fresh package build, test run, Xcode project generation, iOS archive, IPA packaging, simulator test, or physical-device test has been performed for the current branch state.
- The latest attempted macOS workflow jobs were not provisioned by GitHub-hosted runners (runner_id 0 and no execution steps). This is an infrastructure execution gap, not a compiler result.
- Use source-level review and non-macOS static/package checks where available until Actions usage is restored. A successful fresh macOS build and real iPhone/iPad validation remain required.
