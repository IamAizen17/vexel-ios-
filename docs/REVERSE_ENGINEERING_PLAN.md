# Source Reconstruction and Reverse-Engineering Plan

## Scope
Reference: IamAizen17/vexel-editor, default branch main.
Destination: IamAizen17/vexel-ios-.
Goal: reconstruct project semantics, editing operations, rendering behavior, media pipeline, effects and file contracts, then implement native iOS equivalents.

This is a source-repository investigation. REA local MCP/CLI tools are not exposed in the current ChatGPT session. No APK, IPA, executable or runtime capture has been analyzed here. Source inspection must not be described as binary or runtime reverse engineering.

## Method
1. Pin the reference commit SHA and record branch/date for each audit.
2. Inventory modules, build files, schemas, generated registries, tests, examples, assets and native dependencies.
3. Establish canonical project schema and migration history before implementing models.
4. Trace features through UI entry points, view-model commands, model mutations, scene evaluation, renderer and media/export code.
5. Record invariants and side effects: ordering, time ranges, parenting, undo/redo, autosave and asset references.
6. Convert behavior into fixtures and golden vectors with source references.
7. Implement iOS equivalents behind explicit interfaces and compare outputs.
8. Use targeted runtime evidence only when source cannot settle a named question and the exact test is authorized.

## Evidence labels
- Observed in source: directly established by source, schema or configuration.
- Observed in test/fixture: explicitly asserted by repository tests/examples.
- Inferred: derived from multiple paths but not independently demonstrated.
- Unknown: not yet inspected or ambiguous.
- Runtime-confirmed: only when an identified build and exact authorized flow have been run and captured.

Each feature record includes ID, source paths, reference commit, behavior, data contract, edge cases, iOS target, tests, evidence label and open questions.

## Workstreams
A. Project format: root schema, composition, assets, markers, editor state, migrations, archive security and missing-media handling.
B. Editing model: layer types, hierarchy, groups, transforms, trim/split, selection, masks, mattes, blending, keyframes and history.
C. Animation/expressions: value types, interpolation, easing, time domains, syntax, exposed APIs, evaluation order, errors and execution budgets.
D. Scene evaluation: cameras, lights, nested containers, timing, transforms, mattes, effects, 2D/3D conversion and temporal dependencies.
E. Rendering/effects: every effect ID, parameters, defaults, ranges, alpha, color space, scaling, temporal inputs and fallbacks.
F. Media/export: decode, frame scheduling, proxies, waveform/cache, sample rates, synchronization, codecs, muxing, cancellation and cleanup.
G. Advanced native features: extrusion, stabilization, transcription, background removal and model packaging/licensing.
H. UI/interaction: navigation, inspector, timeline gestures, shortcuts, accessibility and adaptive behavior.

## Initial source observations
- Root Gradle configuration includes core and app modules.
- Core is Kotlin/JVM targeting Java 17, not currently configured as multiplatform.
- Project.kt declares format ID knsproj and format version 12.
- KnsprojArchive.kt defines a ZIP with required project.json, optional thumbnail.jpg and referenced assets. Declared limits: 64 MiB project JSON, 8 GiB aggregate uncompressed data and 10,000 entries.
- SceneEvaluator.evaluate(project, time) is documented and implemented as deterministic project/time-to-frame-scene evaluation.
- Compositor.kt implements OpenGL ES and caches textures, video frames, meshes, glyphs, environment maps and temporal slices.
- Export.kt uses Android EGL/OpenGL ES and MediaCodec/MediaMuxer.
- Audio.kt contains a 48 kHz stereo PCM cache/mixing path.
- The generated tools/knsproj/effects.json catalogue contains 73 effect IDs across 13 categories.
- LICENSE is GNU GPL version 3; the Rust crate declares GPL-3.0-only.

This is an initial sample, not an exhaustive source or runtime audit.

## REA escalation criteria
Use REA only when an authorized shipped artifact or runtime trace is required to answer a question source cannot settle. Identify exact artifact, version, authorization, operation and host risk. Prefer static inventory first. Do not launch binaries, install prerequisites, attach to processes or change agent configuration without explicit authorization. Never infer runtime behavior from static evidence.

## Completion criteria
A feature is reconstructed only when source and data contract are documented, defaults and edge cases are identified, tests/fixtures capture expected behavior, iOS implementation has an explicit parity status, and gaps are listed.
