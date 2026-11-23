# Vexel iOS Architecture

## Product contract
Native iPhone and iPad motion-graphics editor. Target full functional parity with the accessible Kinesis Editor reference while introducing an original Vexel interface. Parity means matching project semantics and observable editing/rendering behavior, not copying Android UI.

## Principles
- One project model and editing engine across iPhone and iPad.
- Deterministic scene evaluation: identical project and time produce identical evaluated frame data.
- Preview and export share rendering semantics.
- Preserve unknown project fields and unsupported feature data during import/save.
- Separate UI, project model, scene evaluation, rendering, media I/O and persistence.
- Run expensive work off the main actor.
- Treat archives and imported media as untrusted.

## Proposed modules
- App: SwiftUI lifecycle, navigation and document scenes.
- DesignSystem: tokens, controls and adaptive layout primitives.
- Editor: workspace, timeline, inspector, media browser and gestures.
- Project: Codable model, Vexel archive, KNS importer, validation and migrations.
- Engine: animation, timeline math, expressions, scene evaluation and undo/redo.
- Renderer: Metal render graph, effects, geometry, text and resource management.
- Media: AVFoundation video, AVAudioEngine preview/mixing, image processing and speech.
- Persistence: document coordination, autosave and recovery.
- Diagnostics: logging, performance counters and crash-safe state.
- Tests: unit, compatibility, rendering, media, UI and performance suites.

## Platform mapping
| Reference | iOS |
| --- | --- |
| Jetpack Compose | SwiftUI |
| Kotlin/JVM project core | Swift project and engine modules |
| OpenGL ES 3.0 / GLSL | Metal / MSL |
| MediaCodec / MediaMuxer | AVFoundation |
| AudioTrack and PCM mixer | AVAudioEngine plus deterministic offline mixer |
| Android URI / MediaStore | FileImporter, document picker and FileManager |
| JNI | Swift/C ABI or selectively reused Rust C ABI |
| Rhino expressions | Restricted expression runtime with explicit APIs and resource limits |

These are architectural equivalents, not drop-in replacements.

## Shared-core decision
The reference core is Kotlin/JVM targeting Java 17, not Kotlin Multiplatform. It uses JVM serialization and archive APIs and depends on Rhino. Do not assume it can be linked into iOS unchanged.

Default strategy: implement the canonical engine in Swift, porting documented data semantics and algorithms with compatibility fixtures. Evaluate selective Rust reuse only after auditing iOS targets, FFI safety, licensing and measured value. Avoid adopting Kotlin Multiplatform solely to avoid porting if it adds runtime complexity.

## Renderer contract
The renderer consumes immutable evaluated frame data and does not mutate project state. Organize rendering as a render graph with explicit inputs, outputs, pixel formats, blend behavior, color space and resource lifetimes. Each effect declares its parameter schema, supported formats, color space, temporal requirements and fallback behavior.

## Adaptive workspace
- iPhone: preview-first layout, compact timeline, contextual inspector sheets and touch-first transform controls.
- iPad: resizable workspace regions, expanded multilayer timeline, persistent inspector, media browser and keyboard/trackpad shortcuts.
- Both layouts call identical editing commands and engine APIs.

## Concurrency
Use Swift concurrency and actor isolation around mutable document state. The main actor owns presentation state only. Rendering and decoding use bounded caches and cancellable tasks. Autosave writes snapshots atomically and retains a recoverable previous generation.

## Non-goals
No Android UI port, no Android framework compatibility shims, no feature marked complete merely because a control exists, and no placeholder effects presented as implemented.
