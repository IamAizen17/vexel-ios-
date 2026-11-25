# Vexel engine source audit

## Audit baseline

- Reference: IamAizen17/vexel-editor
- Pinned source revision: 0fe341060cec9710df90bc1ba7fda85006c188d8
- Audit date: 2026-11-23
- Method: source, generated registry, tests/fixtures and UI call-site inspection
- Evidence status: source-observed unless explicitly marked otherwise

This is a source-level reconstruction. No APK/IPA was dynamically instrumented and no Android runtime behavior is claimed as runtime-confirmed.

## Module boundaries

The reference is an Android application plus a reusable Kotlin/JVM core:

- core: project schema, typed layer/effect models, animation, expression execution, editing operations, validation, deterministic scene evaluation, geometry and plugin contracts.
- app: Compose UI, project persistence, media decode, OpenGL ES compositor, audio playback/mixing, export and Android integration.
- native: Rust/JNI functionality for selected performance/native features.
- schema, tools, docs, tests and example projects: compatibility contract, generated registry, validation and regression evidence.

The core targets Kotlin/JVM/Java 17. It is not a Kotlin Multiplatform module. A direct iOS import is therefore not available without restructuring; native Swift implementation is the current port direction.

## Project and archive contract

Observed in core/model/Project.kt:

- The Android source format uses a legacy discriminator and schema version 12. Vexel recognizes it only at the import boundary and immediately converts the document to native Vexel format.
- Root document contains generator, metadata, composition, assets, timeline markers, editor viewport state and ordered top-level layers.
- Composition includes dimensions, floating-point FPS, duration, background, motion-blur settings and 3D environment.
- Assets are typed as image, video, audio, model or font and carry a relative archive path plus optional media metadata and SHA-256.
- Layer types include text, shape, image, video, audio, group, 3D object, 3D model, camera, light and null.
- Layer data includes timing, visibility/lock, sibling parent, blend mode, 2D/3D transforms, effects, masks, matte, transitions, type-specific content and nested children.

Observed in the Android project JSON serializer:

- The reader checks the format ID and integer version before typed decoding.
- Projects newer than version 12 and versions below 1 are rejected; older versions are migrated one version at a time.
- The serializer ignores unknown JSON keys and omits null/default fields on output. This means a future iOS importer should preserve unknown fields separately if round-trip forward compatibility is a product requirement.

Migration history observed in the Android project serializer's migration table:

- v1 to v2 expands the old colorAdjust effect into hueShift, brightnessContrast and saturation entries while preserving the original parameter/keyframe payloads.
- v2 to v3 and v3 to v4 add optional expression/text animator and null/camera fields.
- v4 to v5 adds cyclic easing; v5 to v6 adds 3D materials, lights, camera depth of field, environment, 3D text and packed-alpha video.
- v6 to v7 changes cyclic easing offset semantics and preserves the old phase as cyclic.phase.
- v7 to v8 adds markers and audio/video EQ; v8 to v9 adds editorView, TimeSlice and cutout brush strokes.
- v9 to v10 and v10 to v11 add effect entries; v11 to v12 renames the media roto recipe to cutout while preserving legacy read compatibility.

Observed in the Android archive implementation:

- ZIP container with required project.json, assets/** and optional thumbnail.jpg.
- Limits: 64 MiB project JSON, 8 GiB aggregate uncompressed input and 10,000 entries.
- Entry names are normalized and traversal/absolute/drive-style paths rejected.
- Missing referenced assets are caught by semantic validation after archive reading.
- Export checks missing asset files rather than silently writing an incomplete project.
- Archive timestamps are fixed to make output reproducible.

Observed in core/format/ProjectValidator.kt:

- Structural and semantic validation is separate from JSON decoding.
- Checks include composition bounds, asset IDs/types/paths/existence, marker IDs/times, globally unique layer IDs, parent relationships, hierarchy depth, content/type consistency, keyframe ordering/ranges, expression syntax, effect parameter contracts and other cross-references.
- Validation returns stable issue codes and paths, with both errors and warnings.

## Editing and animation semantics

Observed in core/model/Layer.kt, core/anim/Animatable.kt, core/edit/**:

- Layer time is local to its parent container; a layer is active on its half-open interval [start, start + duration).
- Keyframe times are relative to the owning layer's start.
- Animatable properties are immutable values with optional keyframes, easing, loop mode, expression text and expression-enabled state.
- Loop modes include none, cycle and ping-pong.
- Sampling clamps to first/last keyframe outside the animated interval and interpolates between sorted adjacent keyframes.
- Editing operations are organized in the core rather than directly embedded in UI controls.
- History is snapshot-based with past/future stacks and coalescing support; undo/redo resets coalescing boundaries.
- Timeline operations, keyframe navigation/clipboard, markers, path editing, media swap and property updates have separate core entry points.

## Expression execution

Observed in core/expr/ExpressionEngine.kt:

- JavaScript expressions run through Rhino in interpreted mode.
- The runtime hides Java classes, disables dynamic scope, removes Date and replaces random behavior with seeded deterministic behavior.
- Per-expression source limit: 20,000 characters.
- Per-evaluation interpreted instruction budget: 400,000.
- Maximum interpreter stack depth: 200.
- Compiled scripts are cached with a bounded cache.
- Expression errors preserve line information.

iOS implication: do not evaluate project expressions with unrestricted JavaScriptCore globals. Reproduce the exposed expression API and deterministic seed behavior behind a sandbox with instruction/time/memory limits, or explicitly mark expressions unsupported until an equivalent safe runtime exists.

## UI command/state boundary

Observed in app/ui/editor/EditorViewModel.kt (64,871 characters at the pinned revision):

- The ViewModel owns project/time/playback/selection/multi-selection, undo/redo, editor-view state, media revision, export/caption/media-job state and command dispatch.
- Its command surface covers layer creation/update/delete/duplicate/split/group/ungroup/reorder/parenting, timeline move/trim, keyframes, markers, easing/clipboard, expressions, media replacement/import, audio solo/preview/extraction, presets, plugin commands, captions, camera motion, stabilization, background removal, cutout brush and export.
- Long-running operations are dispatched off the UI thread; project edits flow through the immutable core model/history and are persisted through ProjectStore.

This is the key UI-to-engine mapping target. SwiftUI views should not reimplement these operations as local state mutations.

## Scene evaluation and renderer

Observed in core/scene/SceneEvaluator.kt:

- SceneEvaluator.evaluate(project, time) produces a FrameScene from a project and composition time.
- Evaluation resolves camera, lights, nested containers, inherited transforms, active layer timing, animation, expressions, effects, masks/mattes and render-node content.
- It is designed to be pure and deterministic so preview and export can consume the same scene description.

Observed in app/render/Compositor.kt:

- OpenGL ES 3 compositor consumes FrameScene.
- GPU resource systems include render-target pooling, shaders, text/typeface/glyph resources, image/video textures, meshes, environment maps, temporal slice caches and shadow maps.
- It handles 2D/3D nodes, alpha compositing, backdrop-reading effects, motion blur, shadows and depth-of-field.
- Preview and export share the compositor path; preview can lower effect/sample quality while export uses full-quality settings.

## Effects contract

Observed in core/model/EffectRegistry.kt and the generated Android effect registry:

- 73 effect IDs, 13 categories, one canonical registry.
- Registry entries define stable ID, localized names, category, target, backdrop requirements, typed parameters, defaults, valid ranges, slider ranges, units, choices and conditional visibility.
- Separate effect-picker shortcuts include mask, track matte, transitions and text animators. These are not regular entries in the 73-effect registry.
- Effects may be animatable or static depending on parameter type. Effect serialization is a custom flat JSON contract.
- The iOS UI catalogue was compared against the generated registry: all 73 IDs, names and category assignments match at the audited revision. The current UI still does not expose the full parameter schema or the four shortcuts as functional editor actions.

## Media, audio and export

Observed in app/media/Audio.kt, app/media/Export.kt, core/scene/AudioPlan.kt:

- Audio assets are decoded to 48 kHz stereo signed 16-bit PCM cache for random access and deterministic mixing.
- Audio scheduling is derived from a scene-level audio plan rather than UI state.
- Android preview output uses AudioTrack.
- Export uses EGL/OpenGL ES offscreen rendering and MediaCodec/MediaMuxer.
- Export settings include resolution, quality, audio inclusion, format, optional FPS, transparency and GIF palette/dither options.
- Video export uses resumable five-second segments, progress/cancellation and failure context (frame time/layer ID).

iOS mapping candidates: AVFoundation readers/writers for media, AVAudioEngine for realtime preview, a deterministic offline PCM mixer for export, Metal offscreen render targets, and AVAssetWriter for muxing. Validate codec, alpha, color-space and variable-frame-rate behavior independently.

## Plugin and advanced native boundary

Observed in core/plugin/**, app/plugins/** and native/**:

- Plugin packages have manifests, archive validation, presets/commands and a constrained script host.
- PluginHost checks declared permissions, exposes project data only with project.read, validates returned projects, requires project.write for mutations and prevents plugins from changing the asset set.
- UI includes plugin manager, preset commands and TTS workflows.
- Advanced functionality includes real-camera integration, stabilization, speech/caption workflows, background removal/roto tools, model import and 3D text extrusion.
- Rust/JNI modules must be evaluated individually for algorithm reuse, platform-specific dependencies, licensing and memory/ABI costs. No blanket Rust reuse decision is made.

## Source UI audit findings

The existing SwiftUI port has all 73 effect IDs with matching English names and categories. The main navigation areas and major tool surfaces exist, but this is not yet a one-to-one interaction port:

- Reference onboarding has four pages, skip, language selection (System/English/Portuguese) and theme selection. iOS now represents all four pages, skip and the preference controls; localization is not yet implemented.
- Reference home includes a two-column project grid, import/export, duplicate/delete, recovery and import warnings/errors, presets, settings and plugin installation. iOS now has a persisted project index, project asset directories, duplicate/delete, ZIP import/export and an import compatibility review sheet; recovery snapshots and plugin installation remain incomplete.
- Reference settings include language, appearance, preview resolution/3D quality, proxy usage, storage safety/mirroring/snapshots, fonts, third-party licenses, app version and project format. iOS now represents language, appearance, preview scale/quality, proxies, auto-keyframe, layer names, mirroring and snapshots; font management and a full license browser remain missing, and several preferences are not engine-bound.
- Reference timeline includes gesture-driven navigation, nested group rows, duration-aware clips, pinch zoom, playhead auto-follow, marker flags, frame snapping, clip move/trim handles, keyframe diamonds, PCM waveform, visibility/lock and layer-name display controls. Vexel now has a scrollable native timeline with zoom, seeking, marker flags, nested group-row support, clip move/trim gestures, visibility/lock and keyframe affordances. PCM waveform remains pending the media decoder; timeline edits currently mutate local project state rather than the canonical engine.
- Reference editor connects selection, multi-selection, undo/redo, split/duplicate, keyframes, transforms, viewport modes, real camera, layer tree and export to a ViewModel. iOS now has a source-aligned property tab structure and timeline/effect presentation state, but inspector and editing values are still local presentation state. A real-camera settings page and saved-versions empty state have since been added, but capture/review and snapshot restore are still missing.
- Reference effect picker includes target-compatibility filtering, apply-to selection, search, category grid and shortcuts. iOS has all 73 catalogue entries and now displays the four shortcut affordances, but target filtering, apply-to selection, parameter schema editing and actual insertion are pending.
- Reference plugin sheet exposes installed plugin commands, animation/text/transition presets, TTS and plugin manager. iOS has TTS UI and a plugin page shell, but installed-plugin discovery, preset application and package installation are pending. The current plugin list is sample data.

## Known source discrepancies / audit cautions

- Repository prose mentions a 69-effect library in at least one place, but the generated registry at the pinned commit contains 73. Treat the generated registry and its tests as canonical.
- The current iOS ProjectDocument remains a lossless JSON envelope with a Vexel v2 migration contract, supplemented by typed native schema models. Semantic validation covers composition limits, asset paths/references, duplicate IDs, layer hierarchy, mattes, timing, media ranges, cutout data, editor-view bounds, source scene limits and keyframe ordering. App import acceptance additionally validates known effect parameter types, values and ranges against the canonical effect registry. Expression syntax validation and full source semantic parity remain incomplete.
- A new source field matrix now records root/composition/layer/content contracts, local-time rules, transform semantics, animation/easing, effect serialization, expression sandbox limits, validator issue families, archive limits and source tests to port.
- The Swift validator still does not implement every source rule. In particular, expression syntax checking is unavailable until a constrained expression engine exists, and several type-specific animator/camera/light/effect-target rules remain to be audited. Import processing applies structural/semantic validation before review and effect-aware validation before acceptance; keep the remaining gaps explicit.
- The source Android project/runtime was not built or executed as part of this audit. The iOS repository has since passed GitHub Actions package tests and an iOS Simulator build on the commits recorded in task.md; physical-device behavior remains unverified.

## Next audit targets

1. Read every project migration and serialization rule, not only the current model.
2. Trace EditorViewModel command behavior and UI callbacks for split, parenting, multi-select, timeline drag/snap, camera and effect parameter editing.
3. Convert representative source fixtures to golden project/scene expectations.
4. Inspect all effect implementations and shader sources for parameter semantics and color/alpha contracts.
5. Trace exact media scheduling and export behavior, including cancellation/resume and codec fallbacks.
