# Android format v12 compatibility audit

Audit date: 2026-11-24  
Reference repository: https://github.com/IamAizen17/vexel-editor  
Reference schema: `schema/knsproj-v12.schema.json`  
Kotlin model and serializer sources: `core/src/main/kotlin/dev/kinesis/core/model/` and `core/src/main/kotlin/dev/kinesis/core/format/`

This document records source-verified wire-format facts. It is not a claim of complete semantic compatibility.

## Root document

The Kotlin `KnsProject` model in `Project.kt` serializes these root properties:

- `format`: `knsproj`
- `formatVersion`: integer, current Android reference version 12
- `generator`: optional string
- `meta`: `ProjectMeta` with title, description, author, createdAt and modifiedAt
- `composition`: `Composition`
- `assets`: array of `Asset`
- `markers`: array of `Marker`
- `editorView`: optional editor viewport state
- `layers`: top-level painter-order array

Composition fields include integer width and height, **Double** fps, duration in seconds, serialized color background, motion-blur settings, and a lighting environment. Environment.asset references an image asset ID. Motion blur includes enabled, shutterAngle and samples.

Asset fields are id, type, path, optional name, MIME type, dimensions, duration, hasAudio and SHA-256. Asset paths are project-container-relative and must remain under `assets/`.

## Layer model

The Kotlin `Layer` model uses a required string `id` and a required `type` discriminator. Supported discriminator values are:

`text`, `shape`, `image`, `video`, `audio`, `group`, `object3d`, `model3d`, `camera`, `light`, and `null`.

The common fields are name, start, duration, visible, locked, parent, label, blendMode, motionBlur, transform, transform3d, effects, masks, matte, transitionIn, transitionOut, type-specific content, and recursive `layers` for groups.

Important semantics verified in `Layer.kt`:

- Layer times are seconds relative to the containing composition or group.
- Keyframe times are relative to the layer start.
- Group children are recursive and retain painter order.
- Parent references identify siblings in the same container.
- Matte references identify siblings in the same container.
- Audio is non-visual. Camera, light and null layers are valid discriminators.
- A layer's content object is named after its discriminator, except groups which use `layers`.

## Transforms, animation and easing

2D transforms contain animated anchor, position, scale, rotation and opacity. 3D transforms contain animated anchor, position, rotation, scale and opacity.

The Android serializer supports vector values as fixed-length arrays: `[x, y]` and `[x, y, z]`. Color values are serialized as `#RRGGBB` or `#RRGGBBAA`.

Animation values support static values and animated objects with keyframes, optional loop modes and optional expressions. Keyframes carry time, value and optional easing. Easing encodings include preset strings, `{"cubicBezier":[x1,y1,x2,y2]}`, and `{"cyclic":{"offset":...,"cycles":...,"phase":...}}`.

## Version migrations

The authoritative migration registry is `Migrations` in `KnsprojJson.kt`. It runs one version step at a time:

1. v1 to v2 splits `colorAdjust` into hueShift, brightnessContrast and saturation effects, preserving order and values.
2. v2 to v3 adds optional expression and text property animator support.
3. v3 to v4 adds null layers and camera rotation/aim.
4. v4 to v5 adds cyclic easing.
5. v5 to v6 adds optional 3D material shading, light shadows, camera depth of field, environment, 3D text and packed-alpha video.
6. v6 to v7 changes cyclic easing offset semantics and moves the previous phase shift into `phase`.
7. v7 to v8 adds markers and audio/video EQ.
8. v8 to v9 adds editorView, TimeSlice and cut-out brush data.
9. v9 to v10 adds effects.
10. v10 to v11 adds Copy Background.
11. v11 to v12 renames the packed-alpha media recipe key `roto` to `cutout`, only on media objects carrying an asset reference.

The iOS importer currently implements the nontrivial v1, v6 and v11 transformations recursively. The remaining version steps are optional-field additions and are currently represented by the version advancement. Migration behavior must remain fixture-tested.

## Native Swift schema and source fixtures

- `Packages/VexelCore/Sources/VexelCore/NativeProjectSchema.swift` adds a typed native envelope, composition, assets, markers, layer discriminators, transforms, animatable tracks, keyframes, loop modes, easing encodings, effects and recursive groups.
- All 11 Android layer discriminators are decoded explicitly. Type-specific content is retained under the discriminator-named key; nested content payloads that are not yet fully modelled remain lossless `JSONValue` data.
- Unknown fields are retained at the root, composition, asset, marker, layer, transform, animation-track, keyframe and effect levels.
- `VexelLayerEditing` ports the source duplicate and split identity/reference/timing rules, including fresh descendant IDs, internal parent/matte remapping, keyframe time shifts, transition edge clearing and media sourceStart adjustment.
- `VexelProjectImporter.compatibilityReport(for:)` and `ProjectArchivePayload.compatibilityReport` report known preserved-but-unimplemented features.

`android-v12-kotlin-reference.json` is copied from the Android repository's Kotlin-generated `tools/tests/fixtures/full-kotlin.json`.

`android-video-audio-reference.knsproj` contains the Android repository's checked-in `video-audio` example document plus the exact referenced MP4 and M4A asset blobs from that same source revision. Its ZIP layout follows `KnsprojArchive.kt` (`project.json` and `assets/*`). The fixture is assembled for this test suite; it is **not** an archive captured from an Android app export. A direct app-exported archive is still needed to close that final provenance gap.

## Known gaps in the current iOS bridge

- The editor UI exposes integer FPS although the source model supports fractional Double FPS. The bridge retains the original fractional value unless the user changes the rounded UI FPS.
- Arbitrary source string IDs are mapped deterministically to UUID v5 values for editor identity. The original source ID remains in the document bridge. The core duplicate/split operations generate fresh IDs for copied layers and descendants.
- The typed schema is an additive model layer. The app's current persistence bridge still uses the generic `ProjectDocument` envelope and the interim UI track model; typed accessors are not yet the canonical editing representation.
- Some nested vector coordinate tuples, gradient endpoints, cutout brush frame/stroke internals and effect-specific parameter schemas remain JSON-backed. Their original values are preserved.
- The compatibility report is available to import callers; a user-facing import review screen is not yet connected.
- The archive fixture has real source-repository media payloads and exercises extraction, but it was assembled for tests rather than exported by the Android app itself.

## Compatibility policy

Android format markers and archive entry names are accepted only by `VexelProjectImporter`. Imported data is converted to the native Vexel document envelope. Native project creation, editing, persistence and export must never emit Android format identifiers or Android archive entries.
