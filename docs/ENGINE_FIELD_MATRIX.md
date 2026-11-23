# Vexel Engine Port Contract and Legacy Compatibility Field Matrix

## Audit baseline

- Reference: https://github.com/IamAizen17/vexel-editor
- Pinned source commit: `0fe341060cec9710df90bc1ba7fda85006c188d8`
- Primary implementation: Kotlin/JVM in `core/`; Android UI, OpenGL ES and media APIs live in `app/`.
- This is a source-level audit. It does not claim runtime equivalence, an Android build, or binary reverse engineering.

The reference core is not Kotlin Multiplatform. Its Kotlin/JVM serializers, Rhino expression runtime, Android renderer and Android media/export adapters cannot be imported directly into an iOS target. The correct port boundary is the serialized project contract and deterministic editing/render semantics, reimplemented in Swift.

## 1. Root project document

Source: `core/model/Project.kt`.

| Source field | Type / meaning | iOS model |
|---|---|---|
| `format` | Android source discriminator, recognized only by the Vexel importer | Recognize only inside the Vexel project importer; convert to the canonical Vexel model |
| `formatVersion` | Legacy source schema version 12; Vexel writes its own versioned schema | Source version retained for migrations/reporting |
| `generator` | Optional producer string | Preserve |
| `meta` | Title, description, author, createdAt, modifiedAt | Typed metadata plus unknown-field preservation |
| `composition` | Canvas, frame rate, duration, background, motion blur, environment | Typed composition |
| `assets` | Embedded media/font/model manifest | Typed asset table, unique IDs |
| `markers` | Composition-time ruler markers | Typed markers; order is not semantically significant |
| `editorView` | Viewport mode and free editor camera | Persisted editor-only state, excluded from rendered output |
| `layers` | Top-level painter-order layers | Recursive typed layer tree |

The Android source archive uses `project.json`. Vexel's native archive uses `vexel.json`; the old entry name is accepted only by `VexelCompatibilityImporter`. Unknown JSON must be retained by the importer, even when the current Vexel renderer cannot interpret it. The generic `ProjectDocument` remains a preservation scaffold, not the complete source model.

## 2. Composition contract

Source: `Composition`, `Environment`, `MotionBlurSettings` in `Project.kt`.

- `width`, `height`: integer pixels, source validator range 16...8192.
- `fps`: Double, range 1...120. Do not narrow to integer; fractional frame rates are representable.
- `duration`: seconds, greater than 0 and at most 3600.
- `background`: source Color value.
- `motionBlur`: enabled, shutter angle in degrees, sample count.
- `environment`: optional image asset ID, intensity and vertical rotation for 3D reflection/ambient lighting.
- `frameCount` is rounded from duration × fps and clamped to at least one.
- `frameDuration = 1 / fps`.
- `frameTime(frame) = frame / fps`.
- `snap(time` rounds to the nearest frame boundary.

iOS must preserve fractional FPS and use a rational/timebase representation for AVFoundation scheduling. Avoid assuming every frame rate is an integer.

## 3. Layer tree and timing

Sources: `model/Layer.kt`, `model/LayerTree.kt`.

Layer types in the pinned source:
- `text`, `shape`, `image`, `video`, `audio`, `group`
- `object3d`, `model3d`, `camera`, `light`, `null`

Every layer carries:
- `id`, `type`, `name`, `start`, `duration`
- `visible`, `locked`, optional `parent`, optional timeline `label`
- `blendMode`, `motionBlur`
- `transform` (2D), `transform3d` (3D)
- ordered `effects`, `masks`, optional `matte`, `transitionIn`, `transitionOut`
- one type-specific content object, or `layers` for groups.

Timing invariants:
- A layer is active on the half-open interval `[start, start + duration)`.
- Its `start` and `duration` are relative to its container.
- Keyframe times are relative to the owning layer's start.
- Group children use group-local time. Composition-time offsets are the sum of ancestor group starts.
- Parent and track-matte references resolve to siblings in the same container, not arbitrary IDs across the whole tree.
- Group children retain painter order. Top-level index 0 is drawn first; the last layer is on top.
- 2D/3D null layers are transform-only parents. Cameras and lights are not rendered 3D geometry; `object3d` and `model3d` are.

The Swift model must use recursive value types and explicit tree operations. A flat array of names cannot represent this contract.

## 4. Transform, masks, mattes and transitions

2D transform:
- `anchor`, `position`, `scale`, `rotation`, `opacity`
- Positions are composition pixels with origin at the composition centre and +Y down.
- Scale is a factor (1 = 100%); rotation is clockwise degrees; opacity is 0...1.

3D transform:
- `anchor`, `position`, `rotation`, `scale`, `opacity`
- Coordinates use +X right, +Y down, +Z away from the viewer.
- Euler rotations are applied X, then Y, then Z.

Masks:
- Rectangle or ellipse; add, subtract or intersect.
- Animated position, size, roundness, feather and opacity; inversion and enabled flags.
- Source renderer supports at most four masks per layer.

Mattes:
- Sibling layer reference and alpha, inverted alpha, luma or inverted luma mode.
- Matte source is hidden from ordinary output and rendered into the matte path.

Transitions:
- Fade, directional slides, zoom in/out, spin, blur, wipe left/right.
- Transition duration, easing and optional slide distance.
- In-transition uses the beginning of layer-local time; out-transition uses the end.

## 5. Type-specific content

Source definitions are in `model/Content.kt` and `model/Layer.kt`.

- Text: content, font family/asset, weight, italic, animated size/color/letter spacing, alignment, line height, wrapping, stroke, simple animators and property animators.
- Shape: primitive or path geometry, fill, stroke, gradient and animated geometry parameters.
- Image: asset reference and display/crop properties.
- Video/audio: media asset, source in-point, playback speed, looping/audio parameters and alpha-packed video metadata.
- 3D object: primitive, size, material, optional 3D text mesh configuration.
- 3D model: model asset, size and material.
- Camera: aim mode, transform/projection and depth-of-field settings.
- Light: ambient/directional/point type, color, intensity, position/target, radius and shadow settings.
- Null: 2D or 3D transform-only parent.
- Group: recursive child layers, group transform, opacity, effects, masks and matte.

The initial importer must decode all known content types even if rendering is staged. Unknown content keys must survive a read/write cycle.

## 6. Animation and easing

Sources: `anim/Animatable.kt`, `anim/Easing.kt`, `edit/KeyframeOps.kt`.

An animatable value contains:
- Static `value`.
- Ordered `keyframes`, each with layer-local seconds, typed value and outgoing-segment easing.
- Loop mode: none, cycle or ping-pong.
- Optional expression source and `expressionEnabled`.

Important semantics:
- Zero keyframes means use the static value.
- One keyframe means use that keyframe value at all times.
- Before the first and after the last keyframe, sample the nearest endpoint.
- The easing attached to keyframe i shapes the segment from i to i+1.
- Keyframe equality tolerance is `1e-4` seconds.
- Looping begins only when the sample time passes the final keyframe; ping-pong alternates direction.
- Numeric, Vec2, Vec3 and Color interpolators use the source interpolation contract.
- Keyframe operations include set/upsert/toggle, clear-to-static, move (replacing a collision), set easing, time mapping, clipboard and navigation.

Easing is not just a six-item UI picker. The source supports named presets, cubic Bézier, cyclic easing and a full preset family including overshooting curves. Cubic Bézier uses a UnitBezier solver with Newton iteration and bisection fallback.

The Swift implementation should make sampling pure and deterministic, then test exact boundary values, epsilon collisions, loop cycles and Bézier edge cases.

## 7. Effects contract

Sources: `model/Effects.kt`, `model/EffectRegistry.kt`, the generated Android effect registry.

- The generated registry at the pinned revision is canonical: 73 effect IDs across 13 categories.
- Each definition carries ID, category, localized names, target, backdrop-read requirement and typed parameter definitions.
- Parameter types: number, integer, color, point, boolean, choice and gradient stops.
- Numeric parameters include defaults and valid bounds; choices include allowed IDs.
- Effect JSON is flat: `type`, optional `enabled`, then parameter keys. Values equal to registry defaults are omitted.
- Numeric/color/point values may be animated; boolean, choice and stops use their typed static forms.
- Unknown effect IDs are rejected by the source serializer/registry; iOS import must report them without discarding the original JSON.
- Some effects require backdrop reads; these affect render-graph scheduling.
- `layer_3d` target effects only accept rendered 3D object/model layers.

The iOS app now bundles the exact generated registry JSON from the pinned source revision and builds the picker/detail controls from it. This prevents the UI catalogue and parameter ranges from drifting from the source. The effect renderer and project mutation command are still pending.

## 8. Expressions and determinism

Source: `core/expr/ExpressionEngine.kt` and expression resolver.

The source uses Rhino JavaScript in interpreted mode:
- No Java classes are exposed (class shutter denies access).
- No filesystem, network or process APIs are exposed.
- `Date` is removed.
- `Math.random` is replaced by seeded deterministic random behavior.
- Dynamic scope is disabled.
- Maximum source length: 20,000 characters.
- Maximum interpreted instructions per evaluation: 400,000.
- Maximum interpreter stack depth: 200.
- Compiled scripts are cached (512 entries).

Do not replace this with unrestricted JavaScriptCore evaluation. JavaScriptCore is not automatically equivalent or sandboxed to the same contract. The iOS design must choose between a deliberately compatible constrained interpreter and an explicitly documented subset, with execution limits and no ambient host capabilities.

## 9. Editing operations and history

Sources: `edit/TimelineOps.kt`, `edit/History.kt`, `edit/Props.kt`, `model/LayerTree.kt`.

The source editing model is immutable. Operations return updated project values:
- Add/delete/move/trim/split/duplicate layers.
- Duplicate recursively reassigns IDs and repairs internal parent/matte references.
- Group requires selected layers to be siblings; it offsets child starts into group-local time and removes references that would cross the new group boundary.
- Ungroup restores composition/container timing but may drop group transform/effects; source exposes a lossless check.
- Reorder and move-in-stack preserve painter order.
- Parenting validates type compatibility and cycles and can preserve world transforms.
- Keyframe commands use property descriptors from `Props.kt`; set-value respects animated/static behavior and auto-keyframe.
- Timeline snap points include composition boundaries, markers and layer start/end edges.
- Drag gestures use coalesced history keys so a whole drag is one undo step.
- History defaults to a 200-step limit; equal states are ignored; push clears redo; commit ends coalescing.

The SwiftUI layer must send typed commands to an actor-owned editing store. It must not directly mutate project fields or implement its own parallel undo stack.

## 10. Scene evaluation and rendering boundary

Sources: `scene/SceneEvaluator.kt`, `scene/RenderModel.kt`, `app/render/Compositor.kt`.

The key deterministic boundary is:

`VexelProject + composition time -> FrameScene -> renderer`

Scene evaluation:
- Resolves camera and lights, layer active intervals, nested group timing, parent transforms, animation and expressions.
- Resolves transitions, effects, masks and mattes.
- Builds typed render nodes for 2D layers, 3D layers and groups.
- Resolves media/content references and time-dependent effects.
- Uses deterministic project/time inputs so preview and export can share the same evaluated scene.

The OpenGL ES compositor consumes FrameScene and maintains GPU resource caches for render targets, shaders, fonts/glyphs, image/video textures, meshes, environment maps, temporal slices and shadow maps. It handles blend/composite order, backdrop-reading effects, motion blur, shadows and depth of field.

Do not port Compositor.kt line-by-line. Reproduce the render-node contract and pass graph in Metal. Preview and export should share the evaluator and renderer, with quality settings as renderer configuration rather than separate scene semantics.

## 11. Semantic validator contract

Source: `format/ProjectValidator.kt`.

Validation is broader than JSON shape checking. The pinned source checks:
- Composition size, odd dimensions, FPS, duration and motion-blur ranges.
- Asset IDs, safe paths, existence, references and declared asset types.
- Marker IDs/times and editor-view numeric validity.
- Expression length and syntax.
- Keyframe ordering and keyframe ranges.
- Layer IDs, duplicate IDs, starts/durations, missing content and recursive depth.
- Parent and matte self-reference, missing references, invalid layer kinds and cycles.
- Content/type consistency for text, shapes, media, 3D, null, light and camera.
- Media speed/source ranges and alpha-packed constraints.
- Effect IDs, target compatibility and parameter bounds.
- Mask counts and transition ranges.
- Camera/light count warnings and specialized roto/cutout data.

The Swift validator should use stable issue codes and JSON paths. A project with a warning may still be valid; errors must prevent unsafe import or export. Keep validation deterministic and test it against source fixtures.

## 12. Archive contract

Source: the Android archive implementation.

ZIP entries:
- Native Vexel export: required `project.json`. The legacy Android `project.json` entry is import-only.
- Referenced `assets/<file>`.
- Optional `thumbnail.jpg`.

Source limits:
- Native `vexel.json` and imported legacy document: 64 MiB.
- Aggregate uncompressed entry data: 8 GiB.
- Entry count: 10,000.
- Unsafe absolute paths, drive/colon paths and parent traversal are rejected.
- The writer uses deterministic ZIP timestamps; already-compressed media extensions are stored without recompression.
- Missing referenced assets fail export.
- The archive reader streams non-project entries through a sink and enforces size accounting.

iOS must additionally handle duplicate entries explicitly, verify CRC/checksums, prevent symlink/path escapes, use bounded streaming and write to a staging directory before atomic promotion.

## 13. Existing source test inventory to reuse as parity targets

The pinned source tree includes tests for animation, cyclic easing, editing, frame rates, geometry, effects, keyframe clipboard/navigation, masks, media swaps, null/camera, plugins, real camera, registry artifacts, scene evaluation, time slices, timeline features, cross-language compatibility and expression engine/scene behavior.

Representative test files:
- `AnimationTest.kt`, `CyclicEasingTest.kt`
- `EditingTest.kt`, `TimelineFeaturesTest.kt`, `FrameRateTest.kt`
- `EffectsTest.kt`, `RegistryArtifactsTest.kt`
- `SceneTest.kt`, `TimeSliceTest.kt`, `GeometryTest.kt`
- `ExpressionEngineTest.kt`, `ExpressionSceneTest.kt`
- `FormatTest.kt`, `CrossLanguageTest.kt`
- `PluginTest.kt`, `RealCameraTest.kt`

These are behavioral specifications to translate into Swift tests, not evidence that the iOS implementation currently passes them.

## 14. iOS port implementation order

1. **Import model:** complete typed v12 model, exact serializers, unknown-field preservation, all migrations and structured compatibility report.
2. **Archive:** secure streaming ZIP import/export, asset staging, checksum verification, atomic save, .vexelproj format and import-only Android source adapter.
3. **Validation:** port source semantic validation and stable issue codes.
4. **Editing store:** immutable project commands, layer-tree operations, timeline operations, coalesced history and selection.
5. **Animation:** typed animatables, easing, expressions and keyframe operations.
6. **Scene evaluator:** deterministic FrameScene equivalent with golden test vectors.
7. **Renderer:** Metal pass graph, 2D first, then 3D, masks/mattes, backdrop effects and temporal effects.
8. **Media/audio:** AVFoundation decode, AVAudioEngine preview, deterministic offline PCM mixer and proxies.
9. **Export:** shared render path, AVAssetWriter, cancellation, progress and output validation.

The current app has timeline presentation state and source-driven effect controls, but no canonical VexelProject model, importer, command store, renderer or export pipeline. Do not mark those milestones complete based on UI controls.
