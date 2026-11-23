# Vexel Modular Engine Architecture

## Objective

Replace the UI-first scaffold with a set of independently testable native iOS engines. SwiftUI is an orchestration and presentation layer only. Project semantics live in VexelCore; preview and export share one scene evaluation and render graph.

This is a native reimplementation of the reference contracts. Android APIs, OpenGL ES calls and Kotlin classes are not portable to iOS. The renderer uses Metal and Metal Shading Language (MSL). GLSL is retained as source-reference material only; it is not executed directly by Metal.

## Module graph

```
                         VexelApp
                            |
       +--------------------+----------------------+
       |                    |                      |
  VexelCore            VexelArchive            VexelPlugins
       |                    |                      |
       +----------+---------+----------------------+
                  |
       +----------+-----------+-------------------+
       |          |           |                   |
 VexelRenderer VexelMedia VexelAudio          VexelExport
       |          |           |                   |
       +----------+-----------+-------------------+
                         |
                      VexelCore
```

The actual package dependency direction is acyclic:

- VexelCore: typed project domain, validation, animation, commands/history, deterministic scene evaluation and effect contracts. Foundation only.
- VexelArchive: secure legacy Android archive import and native `.vexelproj` read/write. Depends on VexelCore.
- VexelShaderCompiler: compiler-neutral GLSL ES → SPIR-V → MSL pipeline contracts, input validation, SHA-256 source fingerprints and resource-binding metadata. The glslang and SPIRV-Cross native backends must be linked before runtime translation is enabled.
- VexelRenderer: Metal render graph, MSL library compilation, GPU resource lifetime/caches, 2D/3D passes, masks, mattes and effects. Depends on VexelCore and VexelShaderCompiler.
- VexelMedia: AVFoundation/CoreVideo asset probing, decoding, proxy generation and waveform extraction. Depends on VexelCore.
- VexelAudio: AVAudioEngine preview and deterministic offline PCM mixer. Depends on VexelCore.
- VexelExport: frame scheduling, offscreen renderer orchestration, AVAssetWriter muxing, cancellation and recovery. Depends on Core, Renderer, Media and Audio.
- VexelPlugins: signed package parsing, capability manifest, permission checks and safe preset application. Depends on Core and Archive.
- VexelApp: SwiftUI, document browser, adaptive workspace and dependency composition. It owns no rendering, timeline, media or project business logic.

No engine may import SwiftUI. Renderer must not decode media directly. Media must not mutate projects. Export must not have a second rendering implementation.

## Canonical frame pipeline

1. Decode and validate a versioned project document.
2. Apply typed edit commands to immutable project state.
3. Sample animatable values at composition time, applying group-local time offsets.
4. Evaluate a deterministic FrameScene. This stage must not access Metal, AVFoundation, wall-clock time or UI state.
5. Resolve source media frames through VexelMedia providers.
6. Build and validate a render graph from FrameScene + effect contracts.
7. Execute graph passes on Metal using premultiplied-alpha resources and explicit color-space metadata.
8. Composite output and hand it to preview or export.
9. For export, schedule rational frame timestamps and mux video/audio through AVAssetWriter.

Preview and export use the same scene evaluator, effect implementation, pass ordering and shader functions. Quality settings may change sample budgets, but not visual semantics.

## Render graph rules

- Every pass declares input resources, output resources, pixel format, color space, alpha mode, resolution scale and dependencies.
- A pass may read the backdrop only when its effect contract declares that requirement.
- Backdrop readers create explicit graph dependencies; they may not sample an undefined or partially-written target.
- Blur, glow and other multi-stage effects are expanded into graph passes. A multi-stage effect is not one monolithic shader.
- Temporal effects declare frame dependencies and bounded cache budgets.
- Every render target has an owner and lifetime interval. Transient targets are pooled only when descriptors match and previous use has completed.
- Resource allocation failure must produce a structured render error, not a silent black frame.
- All color arithmetic defines whether values are linear-light or display-referred. Premultiplication is applied exactly once at the input boundary and preserved through compositing.
- GPU resources are created, used and released on the renderer's command queue/device lifetime. No SwiftUI view owns a texture or pipeline state.

## Shader migration contract

The reference project has GLSL ES 3.00 shaders and a shared include convention. Metal does not compile GLSL directly. Vexel now defines a translation pipeline: glslang compiles GLSL ES to SPIR-V, SPIRV-Cross emits MSL plus reflected resource bindings, and VexelRenderer compiles the MSL with the active Metal device. This keeps the original GLSL as the source of truth while targeting native Metal execution. The current Swift package contains the pipeline contracts and Metal library compiler; native glslang/SPIRV-Cross bridges are not yet linked, so translation is not enabled in production builds.

Shared shader ABI:
- UV origin and orientation are explicit.
- Pixel dimensions and composition-space dimensions are distinct.
- Time is layer-local and supplied by the deterministic scene.
- Randomness uses a stable integer hash and explicit seed; no implicit time or random state.
- Texture alpha is premultiplied unless a resource descriptor explicitly says otherwise.
- Sampling uses explicit clamp/repeat behavior and defined filtering.
- Color space is part of the texture descriptor, not an undocumented shader assumption.
- Every effect declares parameter names, units, bounds, defaults and animated/static status from the generated registry.
- Backdrop and temporal inputs are explicit texture bindings.
- Shader variants are compiled at build time where possible; runtime compilation errors are surfaced with effect ID and pass ID.

The first shader families to port are copy/transform, color adjustment, separable blur, masks/mattes, procedural generators, distortion, glow, temporal effects and 3D material/lighting. Deep Glow is a multi-resolution pipeline: threshold/extract, downsample, blur at multiple radii, weighted combine, then premultiplied composite.

## Effect system

The 73-effect generated registry at the pinned reference revision is the metadata authority. The renderer must have a registry mapping every supported effect ID to:
- validated parameter schema and defaults;
- layer target compatibility;
- whether it reads the backdrop;
- pass graph builder;
- shader function(s);
- color/alpha contract;
- preview/export quality policy;
- deterministic seed and temporal dependency policy where applicable.

An effect is not considered implemented because it appears in the picker or has a shader file. It is complete only when the schema, command mutation, scene resolution, render graph, shader, and CPU/GPU tests are connected.

## Error model

Errors are typed by subsystem: project decoding/validation, unsupported feature, missing asset, media decode, graph validation, shader compilation, GPU allocation/execution, audio scheduling and export/muxing. Errors carry stable codes, source object IDs, and recoverability. No engine converts failure into a successful empty result.

## Performance budgets

- iPhone 11 is the minimum performance target; iPad is universal from the start.
- Preview may lower sample count, resolution scale and temporal cache budget. It may not change effect meaning.
- Use frame-local autorelease pools around media decode/export work.
- Bound decoded frame, texture, mesh, glyph and temporal caches by bytes, not only item count.
- Respond to memory pressure by evicting recreatable resources and cancelling nonessential prefetch.
- Avoid full-resolution intermediate targets when a lower-resolution effect chain is mathematically valid.
- Export quality is independent of interactive preview quality.

## Delivery sequence

1. Module boundaries and compileable package graph.
2. Canonical typed project model, legacy schema v12 importer and secure Vexel archive.
3. Animation sampler, timeline commands, history and scene evaluator.
4. Metal device/pipeline/resource layer and baseline 2D graph.
5. Effect registry execution and shader families, with pixel goldens.
6. 3D geometry, cameras, lights, shadows and depth of field.
7. Media decoding/proxies and audio mixing.
8. Shared preview/export scheduling and AVAssetWriter.
9. Plugin package security and platform workflows.

A module is promoted only when it has unit tests, error-path tests and a documented compatibility status. Feature parity is tracked per effect and engine subsystem; no blanket "complete" claim is made.
