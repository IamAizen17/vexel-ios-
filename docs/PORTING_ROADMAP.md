# Vexel iOS Porting Roadmap

## Locked product decisions
- iPhone and iPad from the first supported release.
- Full feature parity with the accessible Kinesis Editor reference.
- Original Vexel interface designed for touch and adaptive iPad workspaces.
- Native project extension: .vexelproj.
- Development workflow supports phone-based editing and cloud macOS builds.

## Phase 0 - Evidence baseline
Pin reference revision; inventory source; audit license/dependencies; map schema, migrations, effects and examples; define feature matrix; choose deployment target after device/API support review.
Exit: architecture, license plan, format contract and test strategy reviewed.

## Phase 1 - Project foundation
Create Swift app/package workspace and universal targets. Define Codable project model and stable IDs. Implement secure ZIP reader/writer for .vexelproj, .knsproj importer, compatibility reporting, schema validation, migrations, asset extraction/relinking, atomic save, autosave and recovery. Build fixtures from legally distributable examples.
Exit: reference projects import, preserve unknown data, save/reopen and pass structural equivalence tests.

## Phase 2 - Editing engine
Implement timeline timebase, layer tree, groups, ordering, selection, visibility, lock, parenting, 2D/3D transforms, keyframes, interpolation, easing, markers, command-based undo/redo, masks, mattes, blend contracts and restricted expressions.
Progress: frame snapping/timecode, actor-serialized timeline state, add/move/reorder/delete/visibility/lock/duration, duplicate with nested ID/reference remapping, group/ungroup with absolute timing preservation, and snapshot undo/redo are implemented. The SwiftUI timeline renders imported layer rows and connects add-text, visibility, duplicate, delete and undo controls. Six timeline tests cover core editing semantics.
Remaining: full selection model, parenting/transform preservation, trim semantics, keyframe operations/interpolation/easing, marker operations, masks/mattes and restricted expression evaluation.
Exit: editing commands pass deterministic unit and serialization tests.

## Phase 3 - Preview renderer
Implement Metal lifecycle/render graph; 2D primitives, text, image and video; compositing, alpha, color management and blend modes; groups, masks and mattes; cameras, lights, geometry and materials; GPU caches and memory-pressure recovery.
Exit: baseline projects render deterministic frames within documented tolerances.

## Phase 4 - Effects and motion
Implement all 73 catalogue IDs with matching parameter contracts. Add echo, time slice, strobe and motion blur. Add presets, fallback policies and golden tests at parameter boundaries.
Exit: no effect silently maps to a placeholder; unsupported cases are explicit.

## Phase 5 - Media and audio
Implement image/video/audio import, AVFoundation decode and scheduling, waveforms, synchronized preview, AVAudioEngine playback, deterministic offline mixing, proxies and relinking.
Exit: mixed-media compositions play in sync within device/resource budgets.

## Phase 6 - Export
Use shared scene evaluation for preview/export, Metal offscreen rendering and AVAssetWriter muxing. Implement presets, dimensions, frame rates, bitrates, color metadata, progress, cancellation, disk checks and partial-output cleanup.
Exit: exports decode correctly and match preview at sampled timestamps.

## Phase 7 - Advanced capabilities
Port stabilization, segmentation/background removal, transcription/captions, 3D text extrusion and model import. Design plugin validation and capability boundaries. Record model provenance, licenses, device support and offline behavior.
Exit: every advanced feature has provenance and dedicated tests.

## Phase 8 - UI and release hardening
Build adaptive workspaces, timeline gestures, touch precision, optional Apple Pencil support, iPad keyboard/trackpad support, VoiceOver, Dynamic Type and reduced motion. Profile memory, GPU, thermal behavior and minimum hardware. Add CI and signed device builds.
Exit: release candidate passes compatibility, rendering, media, accessibility and device performance suites.

## Parity status
Not investigated; Investigated; Specified; Implemented; Unit-tested; Golden-tested; Device-tested; Complete; Deferred with reason.
A feature is not complete because a UI control exists.

## Priority
Preserve project data first, editing semantics second, preview correctness third, export correctness fourth, and visual polish continuously.
