# Renderer and Shader Port Specification

## Source baseline

Reference source is pinned to `0fe341060cec9710df90bc1ba7fda85006c188d8`. Relevant source areas include `core/scene/SceneEvaluator.kt`, `app/render/Compositor.kt`, `app/render/Gl.kt`, and `app/src/main/assets/shaders`.

The reference uses a pure project/time scene evaluator followed by an OpenGL ES 3.0 compositor. The renderer owns shader programs, framebuffer targets, image/video textures, meshes, glyph atlases, environment maps, temporal slices and shadow maps. Scene evaluation handles layer activation, local time, parent/group transforms, mattes, masks, transitions, effects and time-slice/echo dependencies.

## Native renderer decomposition

| Component | Responsibility | Must not own |
|---|---|---|
| SceneEvaluator | Pure project/time to render nodes | GPU/media/UI |
| RenderGraphBuilder | Convert nodes/effects into ordered passes | Metal command execution |
| MetalDeviceContext | Device, queues, capabilities | Project state |
| ShaderLibrary | MSL functions and pipeline states | Effect parameter editing |
| TexturePool | Reusable transient targets | Persistent source assets |
| AssetTextureCache | Decoded still images | Video decode |
| VideoFrameProvider | Current decoded frame | GPU graph policy |
| GeometryRenderer | 2D quads, paths, meshes and text geometry | Timeline edits |
| MaskMattePasses | Mask composition and track mattes | Project mutation |
| EffectPasses | Effect-specific pass builders | UI catalogue |
| LightingRenderer | Camera, lights, shadows, depth and materials | Scene evaluation |
| TemporalCache | Echo/time-slice frames with byte budget | Unbounded history |
| Compositor | Execute graph and composite final output | Project serialization |

## Pass families

- Base: clear/background, solid, image, video, text, shape, group.
- Transform: affine 2D, 3D model/view/projection, camera.
- Compositing: blend modes, opacity, premultiplied alpha.
- Matte/mask: alpha/luma, inverted modes, rectangle/ellipse/path masks, feather.
- Color: brightness/contrast, exposure, saturation, vibrance, hue, tint, balance, gradient map.
- Blur: separable Gaussian, directional, radial, lens, depth of field.
- Glow: threshold/extract, multi-scale blur pyramid, weighted combine, additive composite.
- Distortion: warp, ripple, twirl, pinch/bulge, bend, glass, chromatic aberration.
- Procedural: noise, fractal noise, grid, halftone, scanlines, grain, dither.
- Stylize: edge, emboss, sketch, posterize, pixelate, VHS/glitch families.
- Temporal: motion blur, echo, strobe, time-slice.
- 3D: mesh/material, environment, shadow depth, shadow resolve, depth, DOF.

## Shader parity checklist

Each effect receives a record containing:
- source shader(s) and pinned source hash;
- MSL implementation path;
- parameter-to-uniform mapping and unit conversions;
- source/target coordinate conventions;
- alpha and color-space behavior;
- number and order of passes;
- deterministic seed behavior;
- target layer types and backdrop dependency;
- reference fixture and image tolerance;
- iPhone 11 GPU time/memory measurements.

No shader is marked ported until it compiles on the minimum deployment target, passes parameter boundary tests, matches reference frames within an approved tolerance and survives memory-pressure tests.

## Deep Glow reference pipeline

The source combine shader receives three blurred scales, normalized weights, intensity and color. The MSL port must preserve the source operation order and premultiplied-alpha constraints. The complete effect also requires extraction/threshold and blur pyramid passes. Porting only the combine shader is not a complete Deep Glow implementation.

## Validation strategy

- Compile all MSL functions in CI for the iOS simulator/device SDK.
- Unit-test graph topology, missing inputs, cycles, target aliasing and backdrop dependencies.
- Render deterministic 1x1, gradient, transparent-edge, checkerboard and HDR boundary fixtures.
- Compare output images against reference-generated fixtures with per-channel tolerances and a perceptual metric.
- Run preview/export parity checks at the same rational timestamps.
- Profile GPU duration, peak transient bytes, texture dimensions and thermal behavior on iPhone 11 and iPad.
