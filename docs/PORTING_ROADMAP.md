# Vexel iOS Porting Roadmap

## Locked product decisions
- iPhone and iPad from the first supported release.
- Full feature parity with the Android reference editor.
- Original Vexel interface designed for touch and adaptive iPad workspaces.
- Native project extension: .vexelproj.
- Development workflow supports phone-based editing and cloud macOS builds.

## Stage 1 - Product foundation and integrity (current)
Close P0 project-integrity work: effect-aware semantic validation, archive compatibility evidence, unknown-field preservation, asset lifecycle and truthful build/test documentation. The source app remains a behavioral reference only; Vexel's final UI is an original Alight Motion-inspired design, not a Compose screen port.

Exit: imports are validated before acceptance, project data survives supported round trips, archive limitations are documented, and CI verifies package tests plus the iOS Simulator build.

## Stage 2 - Source contract and compatibility audit
Pin source files, read source project serializers and every migration, inspect schemas and representative valid/invalid fixtures, map ViewModel commands to core operations, inspect every effect implementation and shader, and trace media/export behavior. Record unknowns and evidence labels.

Exit: typed field matrix for the legacy Android schema v12, editing operation map, effect parameter contracts, archive limits, and representative golden fixtures.

## Stage 3 - Project foundation
Create typed Swift project models with unknown-field preservation. Implement secure native `.vexelproj` read/write and Vexel project compatibility importer, semantic validation, migrations, compatibility reports, asset extraction/relinking, atomic save, autosave and recovery.

Exit: source projects import, preserve unknown data, save/reopen and pass structural equivalence tests.

## Stage 4 - Editing engine
Implement timeline timebase, layer tree, groups, ordering, selection, visibility, lock, parenting, 2D/3D transforms, keyframes, interpolation, easing, expressions, markers, command-based undo/redo, masks, mattes and transitions.

Exit: editing commands pass deterministic unit and serialization tests.

## Stage 5 - Deterministic scene evaluator
Port project/time -> FrameScene independently of GPU APIs. Resolve nested groups, timing, inherited transforms, cameras, lights, animation, expressions, transitions, effects, masks and mattes.

Exit: source golden vectors match evaluated nodes, transforms, opacity, content, effect parameters and active intervals.

## Stage 6 - Metal preview renderer
Implement Metal lifecycle/render graph; 2D primitives, text, image and video; compositing, alpha, color management and blend modes; groups, masks and mattes; cameras, lights, geometry and materials; GPU caches and memory-pressure recovery.

Exit: baseline projects render deterministic frames within documented tolerances.

## Stage 7 - Effects and motion
Implement all 73 catalogue IDs with matching parameter contracts, plus mask, track matte, transitions and text animators. Add echo, time slice, strobe and motion blur. Add presets, fallback policies and golden tests at parameter boundaries.

Exit: no effect silently maps to a placeholder; unsupported cases are explicit.

## Stage 8 - Media and audio
Implement image/video/audio import, AVFoundation decode and scheduling, waveforms, synchronized preview, AVAudioEngine playback, deterministic offline mixing, proxies and relinking.

Exit: mixed-media compositions play in sync within device/resource budgets.

## Stage 9 - Export
Use shared scene evaluation for preview/export, Metal offscreen rendering and AVAssetWriter muxing. Implement presets, dimensions, frame rates, bitrates, color metadata, progress, cancellation, disk checks and partial-output cleanup.

Exit: exports decode correctly and match preview at sampled timestamps.

## Stage 10 - Advanced capabilities and release hardening
Port stabilization, segmentation/background removal, transcription/captions, 3D text extrusion and model import. Design plugin validation and capability boundaries. Complete accessibility, keyboard/trackpad, optional Pencil, memory/GPU/thermal profiling, signed builds and release checks.

Exit: feature-by-feature parity is measured on supported hardware and documented.

## Parity status
Not investigated; Investigated; Specified; Implemented; Unit-tested; Golden-tested; Device-tested; Complete; Deferred with reason.
A feature is not complete because a UI control exists.

## Priority
Preserve and validate project data first; establish one canonical editing state and complete editing semantics next; design and implement the original Vexel UI against stable command/view-model contracts in parallel; then deliver deterministic scene evaluation, preview rendering, effects, media and export. Visual polish continues throughout.
