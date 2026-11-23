# Vexel iOS port status

Last reviewed: 2026-11-24  
Reference repository: https://github.com/IamAizen17/vexel-editor  
Reference revision audited: 0fe341060cec9710df90bc1ba7fda85006c188d8  
iOS implementation branch: feat/modular-engine-architecture  
Related pull request: https://github.com/IamAizen17/vexel-ios-/pull/2

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

These are initial workspace operations. They are not yet backed by a complete canonical editing engine. Several operations have known semantic gaps, including keyframe data containing timestamps rather than animated property values, incomplete nested-track selection/editing, and split/group behavior that needs source-compatible semantics.

### Project data, persistence, and archive groundwork

- `VexelProjectItem` and timeline tracks are Codable.
- Project metadata and workspace model state are persisted as an index under Application Support.
- A project/document bridge converts between the interim editor model and a generic JSON-backed `ProjectDocument`.
- The bridge attempts to preserve unknown root fields and existing top-level layer fields.
- `ProjectDocument` accepts native Vexel format v1 and legacy Android format versions up to v12 for import, validates core composition bounds, asset paths, and recursive layer IDs.
- `VexelArchive` uses ZIPFoundation and reads/writes ZIP archives containing `project.json` and referenced `assets/` files.
- Archive import is connected to the project file importer; archive export is connected to the project-card share flow.
- Archive code includes entry-count and uncompressed-size limits, relative-path checks, duplicate-entry rejection, symlink rejection, and missing-asset checks.

Important compatibility qualification: legacy Android import is not yet verified against real source projects. The bridge currently assumes several layer field names and shapes, does not decode keyframe/property animation data, and does not have real Android project fixtures. Do not claim round-trip compatibility with arbitrary legacy Android projects until the source schema and fixture tests prove it.

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

### P0: Stabilize Vexel project persistence and legacy Android import

- Audit the actual Kotlin data classes, serializers, sample projects, and migration code for legacy Android v12. Replace guessed field mappings with source-verified mappings.
- Add real legacy Android project fixtures and test import, export, and round-trip preservation.
- Define explicit typed Swift models for composition, assets, layer variants, transforms, effects, masks, mattes, transitions, markers, keyframes, easing, expressions, and editor state.
- Preserve unknown fields recursively, including nested group layers. The current bridge only indexes existing top-level layer objects for preservation.
- Correct the current audio-layer bridge behavior: the serializer currently changes an audio layer's discriminator to `null` when its audio payload is absent.
- Preserve source IDs when duplicating/splitting layers without creating duplicate IDs. Define how source IDs map to native UUIDs.
- Validate all numeric values for finiteness and bounds before converting them to integer or rendering types.
- Add schema-version migrations and explicit unsupported-feature handling.
- Verify asset path semantics against Android-generated archives and validate every referenced asset on import.
- Harden ZIP handling: reject all unsupported special entry types, use overflow-checked size accumulation, enforce practical per-file and compression-ratio limits, and make destination replacement failure-safe.
- Make archive import transactional so a failed import does not leave partial asset directories or project records.
- Confirm the app's file importer/exporter supports the legacy Android import and native `.vexelproj` export and document the distinction between native Vexel format and legacy Android import compatibility.

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
- The project/document bridge is provisional. It guesses parts of the legacy Android layer schema, omits keyframe/property animation decoding, and does not preserve unknown nested-layer fields reliably.
- legacy Android format acceptance in validation is only a format/version gate. It does not establish full KNS v12 semantic compatibility.
- Archive read/write code exists and is connected to UI flows, but must receive security hardening and real Android fixture tests before being treated as production-ready.
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
