# Native iOS engine port plan

## Goal

Port the reference editor's project semantics and editing/rendering behavior to a native universal Swift application. The source core is Kotlin/JVM, not Kotlin Multiplatform, and the Android UI/media/render layers depend on Android APIs. The port therefore needs a native Swift implementation with compatibility tests, not a direct module import.

## Architectural target

- SwiftUI: presentation only. UI sends typed commands and observes immutable snapshots.
- VexelCore Swift package: project model, migrations, validation, animation sampling, editing commands, history, scene evaluation and effect contracts. No UIKit/SwiftUI dependencies.
- VexelArchive: ZIP read/write, asset extraction, checksums, atomic save/recovery and format adapters.
- VexelRenderer: Metal render graph, shader/effect library, 2D/3D geometry, text, masks, mattes, camera/light and GPU resource caches.
- VexelMedia: AVFoundation image/video/model/audio import, proxy generation, frame decoding, audio scheduling and waveform extraction.
- VexelAudio: AVAudioEngine realtime preview and deterministic offline mixer.
- VexelExport: Metal offscreen render + AVAssetWriter muxing, progress, cancellation, segmented recovery and export presets.
- VexelPlugins: manifest/archive validation and a capability-limited extension model. Do not execute arbitrary plugin scripts in the app process.
- VexelApp: adaptive iPhone/iPad workspace, document browser, accessibility and platform integration.

## Source contract reference

See [ENGINE_FIELD_MATRIX.md](ENGINE_FIELD_MATRIX.md) for the pinned v12 field matrix, layer/time invariants, typed animation/easing contract, effect serialization, Rhino sandbox limits, validator issue families, archive limits and source test inventory.

The source core is immutable Kotlin data. `History<T>` stores a 200-step bounded history by default, ignores equal states, clears redo on push and coalesces consecutive operations with the same non-null gesture key. Timeline operations include move, trim-start (including shifting keyframe/media content), trim-end, split, duplicate with recursive ID remapping, group/ungroup, reorder and parent assignment. Port those semantics into typed commands; do not make SwiftUI local state the source of truth.

## Compatibility boundary

Keep .vexelproj as the native project extension, but make its versioned model able to represent the full source project semantics. A Vexel archive should carry a declared source compatibility record and preserve unknown JSON fields. The legacy Android import adapter must read supported source versions, map representable data losslessly where possible, and return structured warnings for every unsupported or lossy field. Never silently drop layers, effects, animation, media or plugin data.

The current generic ProjectDocument is only a preservation scaffold. It is not yet the canonical model, importer or validator.

## Milestones

### E0 - Complete source contract
- Pin every source file and generated schema used.
- Read the source project serializers, all migrations, validator, archive implementation and real fixtures.
- Build a typed field matrix for Project, Composition, Asset, Layer, content types, transforms, effects, masks, mattes, transitions, markers, editor view and plugin metadata.
- Map every editing UI action to ViewModel method, core operation and state transition.
- Build canonical JSON fixtures and semantic validation expectations.
Exit: no unknown top-level or layer fields in the v12 compatibility matrix.

### E1 - Canonical Swift model and format adapter
- Introduce typed Swift project models with JSONValue extension preservation.
- Implement source v12 decoding and explicit migrations from supported earlier versions.
- Implement semantic validation equivalent to source validation.
- Implement secure ZIP import/export with bounded streaming, duplicate-entry policy, safe paths, CRC/hash verification and atomic directory promotion.
- Implement native `.vexelproj` archives and import-only legacy Android compatibility.
Exit: fixtures import, validate, save/reopen and compare structurally; all asset references resolve.

### E2 - Editing domain
- Port immutable Animatable sampling, easing, cycle/ping-pong, keyframe epsilon and layer-local time.
- Port layer-tree invariants, parent/child transforms, groups, ordering, selection and multi-selection.
- Implement command-based edits, coalesced history, undo/redo, split/trim/duplicate/group/parent, masks/mattes, markers and keyframe clipboard/navigation.
- Add deterministic expression interface; initially support a safe documented subset if full Rhino parity is not feasible.
Exit: unit/property tests match source fixture outputs for all supported editing operations.

### E3 - Deterministic scene evaluator
- Port pure project/time -> FrameScene semantics independently of GPU code.
- Resolve timing, nested groups, transform inheritance, 2D/3D transforms, cameras, lights, animation, expressions, transitions, effects, masks and mattes.
- Keep scene evaluation free of SwiftUI, AVFoundation and Metal objects.
Exit: source golden vectors compare scene nodes, transforms, opacity, content, effect params and active intervals.

### E4 - Metal preview renderer
- Design a Metal render graph matching source pass order and premultiplied-alpha contract.
- Port resource caches and memory-pressure handling for textures, video frames, meshes, glyphs, environment maps, temporal slices and shadows.
- Implement baseline 2D layers and blend modes before 3D, backdrop effects and temporal effects.
- Add pixel golden tests with documented tolerances and deterministic seeds.
Exit: representative source scenes render matching frames on iPhone and iPad.

### E5 - Effects and advanced scene features
- Port all 73 registry entries from canonical parameter metadata and source shader behavior.
- Include mask, track matte, transitions and text animators as separate editing contracts.
- Implement motion blur, echo/time-slice/strobe, 3D lighting/shadows/depth of field, text animators and model materials.
Exit: every effect has parameter, target, backdrop, alpha/color and temporal tests.

### E6 - Media and audio
- Implement coordinated AVAssetReader/AVPlayerItemVideoOutput or equivalent frame provider behind an asset decoder interface.
- Build proxies without changing export source selection.
- Port 48 kHz stereo mixing semantics and scheduling, then realtime AVAudioEngine preview.
- Test sample-rate conversion, channel layouts, offsets, fades, looping, volume automation and sync drift.
Exit: reference test scenes play and mix deterministically within device budgets.

### E7 - Export
- Use the same scene evaluator and Metal render graph as preview.
- Add AVAssetWriter output, audio muxing, frame-rate/resolution/quality controls, transparency-capable paths where supported, progress and cancellation.
- Port resumable segment design only after content/settings hashing and partial-file cleanup are tested.
Exit: exported frames and audio match preview at sampled points; interrupted export recovers safely.

### E8 - Platform and advanced capabilities
- Implement Files document provider, autosave, crash recovery, snapshots, font management, camera capture and accessibility.
- Port stabilization, segmentation, transcription, 3D text extrusion and model import only after model/dependency/license audit.
- Define plugin sandbox, permissions, package format and signing.
Exit: feature-by-feature parity is measured on supported hardware and documented.

## Critical design decisions

1. Do not port Android UI code. The UI port is SwiftUI and must stay decoupled from the engine.
2. Do not port Compositor.kt line by line. Reproduce its render contract and pass graph in Metal.
3. Do not run unrestricted JavaScript. Rhino's class shutter, deterministic random, instruction budget and stack limit are part of the source behavior. Use a constrained interpreter or document a deliberate compatibility subset.
4. Do not conflate source v12 and Vexel v1. Define field mapping and migration rules before enabling import.
5. Do not make placeholder UI appear functional. Until a command is connected, disable it or state the limitation.
6. Do not reuse GPL source fragments without maintaining attribution and corresponding-source obligations. Audit Rust/native dependencies independently.

## Immediate implementation order

1. Complete the UI audit and remove misleading placeholder success paths.
2. Implement typed VexelProject decoding with legacy Android compatibility and semantic validation.
3. Add secure archive reading and fixture-based import tests.
4. Add typed editing commands and undo/redo.
5. Add deterministic animation sampling and scene evaluator.
6. Only then build the Metal renderer.

## Verification gates

- Source fixture import and round-trip tests.
- Property-based tests for timing, animation, layer trees and history.
- Malformed ZIP, traversal, duplicate entry, oversized JSON, decompression budget and missing asset tests.
- Scene golden vectors and renderer pixel goldens.
- Audio synchronization and export decode tests.
- iPhone 11-class memory/thermal profiling and iPad layout/input tests.
- CI build/test and signed IPA install test.
