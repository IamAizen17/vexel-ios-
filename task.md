# Vexel iOS port status

Last reviewed: 2026-11-23
Reference repository: https://github.com/IamAizen17/vexel-editor
Reference revision audited: 0fe341060cec9710df90bc1ba7fda85006c188d8
iOS implementation branch: feat/modular-engine-architecture

This is the implementation handoff. “Added” means present in the iOS codebase; it does not imply complete parity with Android.

## Added in the current iOS codebase

### Application and interface
- Universal SwiftUI application structure for iPhone and iPad.
- Four-page onboarding flow with skip, language preference, and appearance preference controls.
- Project home with Projects, Presets, and Settings destinations.
- Composition creation UI and editor workspace.
- AMOLED graphite interface with teal/cyan accents and light appearance palette.
- Reusable material-backed panels, gradient edge treatments, consistent rounded controls, and press feedback.
- Spring-based navigation transitions between onboarding, home, and editor; destination changes animate with a native spring.
- Reduce Motion support switches navigation to opacity transitions and removes press scaling when the accessibility preference is enabled.
- Timeline UI with track rows, nested group display, zoom, ruler, playhead, marker affordances, clip move/trim gestures, visibility/lock affordances, and keyframe markers.
- Layer and shape tool panels, text-layer creation UI, effect browser, effect detail sheet, property panel, graph/curve surfaces, composition settings, and export surface.
- Saved easing preset storage (up to 24 entries).
- Source effect catalogue bundled from the pinned reference registry: 73 effect IDs across 13 categories.

### Editing operations currently wired to project state
- Add a visual layer, text layer, and 2D shape layer.
- Duplicate and delete selected top-level layers.
- Group the selected top-level layer with its adjacent sibling.
- Split a selected top-level layer at the playhead.
- Add a keyframe timestamp to the selected track at the current frame.
- Select a layer and toggle its visibility or lock state.
- Add and remove effect IDs from a selected layer's effect stack.
- Undo and redo using in-memory project snapshots.
- Advance the playhead during playback and stop or loop at composition duration.

### Engine and package foundations
- Swift packages established for VexelCore, VexelArchive, VexelRenderer, VexelShaderCompiler, VexelMedia, VexelAudio, VexelExport, and VexelPlugins.
- JSON value representation and an initial Vexel project document model with structural validation.
- Initial archive, media, audio, export, and plugin contracts.
- Initial render graph validation and Metal renderer scaffolding.
- Initial Metal shader functions for fullscreen copy, brightness/contrast, Gaussian blur, and multi-scale glow combination.
- Shader translation interfaces and tests.
- Effect registry verification and engine/shader coverage verification scripts.
- GitHub Actions workflow builds/tests engine packages, generates the Xcode project, archives for generic iOS devices, and uploads an unsigned IPA artifact.

## Reference feature parity still required

The Android source has a reusable Kotlin/JVM core and Android integration. The Kotlin core is not Kotlin Multiplatform, so the iOS implementation must reproduce the contracts in Swift.

### Project model, persistence, and compatibility
- Port the complete source KNS project v12 schema to the Vexel project format.
- Implement typed models for composition, assets, all layer types, transforms, effects, masks, mattes, transitions, markers, keyframes, easing, expressions, and editor state.
- Implement versioned migrations and unknown-field round-trip preservation.
- Implement secure ZIP archive import/export, path traversal protection, size/entry limits, asset integrity checks, and missing-asset validation.
- Persist projects, autosaves, snapshots, recovery state, and media assets on-device.
- Add import/export and migration fixtures from real source projects.

### Editing and animation engine
- Replace view-local mutations and workspace-owned undo stacks with a canonical actor-owned command store.
- Port timeline reorder, move, trim, split, duplicate, group/ungroup, parenting, multi-selection, snapping, ripple edits, and coalesced history.
- Implement typed property descriptors and set-value/auto-keyframe behavior.
- Port animation sampling, keyframe clipboard/navigation, cubic Bézier easing, cyclic easing, loop and ping-pong semantics, and deterministic tests.
- Implement a constrained deterministic expression evaluator. Do not expose unrestricted JavaScriptCore or host APIs.
- Implement deterministic scene evaluation from project plus composition time to a renderable frame scene.

### Rendering and effects
- Implement the complete Metal render graph and shared preview/export renderer.
- Complete GLSL-to-SPIR-V-to-MSL translation with a pinned SPIRV-Cross toolchain, diagnostics, shader validation, caching, and uniform mapping.
- Port all source shaders and all 73 effects, including typed parameters, defaults, ranges, backdrop requirements, and target restrictions.
- Implement masks, track mattes, transitions, blend modes, motion blur, time slices, shadows, depth of field, HDRI, 3D materials, text extrusion, and GLB model rendering.
- Load and compile bundled Metal shader resources through the renderer at runtime.
- Add GPU image regression tests and performance/memory budgets for iPhone-class hardware.

### Media, audio, captions, and export
- Implement image/video/audio/model/font import and asset management.
- Implement AVFoundation decoding, frame caching, proxy generation, waveform extraction, and random-access seeking.
- Implement realtime preview audio and deterministic 48 kHz stereo mixing.
- Port speech recognition/caption generation and SRT import/export.
- Implement stabilization, background removal, cutout brush, and real-camera workflows where platform APIs and licensing allow.
- Implement MP4 export through Metal and AVAssetWriter, including progress, cancellation, resumable jobs, and codec/color-space validation.
- Implement GIF, image-sequence, and other source export formats where supported.

### Product and platform integration
- Implement persistent project grid, duplicate/delete, recovery, presets, and secure project import/export.
- Implement localization, font management, settings persistence, plugin installation/permissions, and third-party license browser.
- Validate iPhone compact layouts, iPad expanded layouts, rotation, multitasking, accessibility, Dynamic Type, VoiceOver, and Reduce Motion.
- Add real-device performance and thermal tests.

## Known issues and limitations

- The editor VexelProjectItem and timeline tracks are an interim UI model, not the canonical VexelCore.ProjectDocument model.
- The current project list and edits are in memory. Projects do not persist across launches.
- ProjectDocument is an initial Vexel v1 JSON structure, not a complete reader/writer for the Android KNS v12 format.
- The Vexel project ZIP archive adapter is not implemented; import/export controls are placeholders or disabled.
- Undo/redo covers current workspace snapshot operations only. Timeline gesture coalescing and all source editing commands are not represented.
- Playback currently advances the playhead; it does not render animated scene frames or play audio.
- Adding an effect stores its identifier only. Effect parameters are not serialized or rendered.
- The effect catalogue is complete at the ID/name/category level, but effect execution and full parameter binding are incomplete.
- Transform, text, mask, transition, and graph controls are not fully connected to the project model.
- Media, audio, 3D, camera, captions, elements, plugins, stabilization, cutout, and export are incomplete or disabled. A media picker surface does not yet mean media is imported into the project.
- Metal renderer and shader compiler are scaffolding. Initial shader functions do not represent full source shader parity; GLSL translation is not integrated end-to-end.
- No Android APK/IPA binary or runtime instrumentation was used for this source audit. Findings are source-level only.
- CI success means package tests and generic unsigned iOS archive/package workflow passed. It does not prove installation, signing, or real-device runtime behavior.
- The generated IPA is unsigned and requires valid signing/provisioning or compatible sideloading before installation.
- GPL-3.0 obligations and third-party/native dependency licenses must be reviewed before distribution.

## Verification record

- Latest verified workflow before the current UI commits: run 45282736871, commit 02b83e5f40b29de404b4df91b57b033fd51a0597.
- Swift package build/tests: passed.
- Effect registry verification: passed.
- Engine/shader coverage verification: passed.
- XcodeGen project generation: passed.
- Generic iOS device archive: passed.
- Unsigned IPA packaging and artifact upload: passed.
- Real iPhone/iPad installation and runtime testing: not performed.
- The current UI changes require a fresh CI run; do not treat the previous run as verification of these changes.
