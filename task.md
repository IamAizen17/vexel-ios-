# Vexel iOS engineering plan

Last reviewed: 2026-11-24
Reference repository: https://github.com/IamAizen17/vexel-editor
iOS implementation repository: https://github.com/IamAizen17/vexel-ios-
Active implementation branch: `feat/modular-engine-architecture`
Related engine PR: https://github.com/IamAizen17/vexel-ios-/pull/2

This is the active project handoff, implementation status, and prioritized backlog. A checked item means the implementation exists and has supporting evidence; it does not automatically mean complete source parity or production readiness. Keep implementation status, test status, and device validation separate.

## 1. Product decisions (fixed)

- Vexel is an **iPhone and iPad application only** (iOS/iPadOS).
- Native implementation: Swift, SwiftUI, Metal, AVFoundation, and Apple platform frameworks.
- No Android application, Android UI, Kotlin product architecture, or macOS product target.
- `IamAizen17/vexel-editor` is a read-only behavioral and file-format reference. Android compatibility is limited to isolated legacy project import where explicitly supported.
- Native project extension: `.vexelproj`; archive document: `vexel.json`; native format identifier: `vexelproj`, version 2.
- Apple document type: `com.ragestudios.vexel.project`; bundle identifier: `com.iamAizen17.vexel`.
- Preserve unknown project data during import/edit/save. Never silently discard unsupported content.
- Preview and export must eventually use the same deterministic scene evaluation and rendering pipeline.
- Do not mark a feature complete because a button, panel, registry entry, protocol, or shader stub exists. Require working behavior and appropriate tests.

## 2. Product design direction

### New UI direction: Alight Motion-inspired, Vexel-original

The current UI shown in the November 24 screenshots is the existing baseline only. It is **not** the target design and must not be treated as a design constraint. The next UI should be a substantial redesign, with interaction patterns and editing-workflow inspiration from Alight Motion rather than copying the Android source application's interface.

Design principles:
- Build an original Vexel interface informed by Alight Motion's mobile motion-editor workflow: direct access to the composition, timeline, layers, keyframes, tools, and property controls.
- Do not reproduce Alight Motion branding, logos, proprietary icons, exact screen layouts, or pixel-for-pixel assets. Use original Vexel components and visual language.
- Keep the existing Vexel identity: AMOLED/near-black foundation, restrained teal/mint accent, high-contrast typography, deliberate spacing, and compact professional controls. No purple theme or anime styling.
- Prioritize the editing canvas and timeline over decorative dashboard cards.
- Make common editing actions reachable with one or two taps. Avoid oversized cards and excessive empty space in the editor.
- Design for touch first, with precise gesture targets, clear selection states, undo/redo, and contextual tool panels.
- iPhone uses a compact, layered workflow; iPad uses the additional width for persistent inspector/tool panels and a more expansive timeline. Both use the same interaction model and project format.
- Support portrait and landscape orientations where appropriate, safe areas, Dynamic Type, VoiceOver, Reduce Motion, and iPad multitasking.
- Use real project state and real actions in the UI. No decorative controls that imply functionality that does not exist.

### Screens and interaction areas to redesign

1. **Projects/home:** compact project library, search/sort, recent projects, create/import actions, clear project thumbnails and metadata. Reduce the current oversized create card and unused vertical space.
2. **Preset/create flow:** searchable composition presets, custom dimensions/FPS/duration, and a clear creation confirmation. Presets must populate real composition settings.
3. **Editor workspace:** composition preview as the visual focus; compact top bar for navigation, project title, undo/redo, workspace controls and export; timeline and layer stack immediately accessible.
4. **Timeline:** multi-track clips, playhead/time ruler, selection, trim/move, snapping, markers, keyframes, track visibility/lock, horizontal zoom and contextual clip actions. Timeline must remain usable on iPhone.
5. **Tool/action dock:** contextual actions for adding media, shapes, text, audio, effects and other supported layer types. Tool availability must reflect actual implementation.
6. **Properties/inspector:** transform, opacity, blend, timing, text, shape, effect and animation controls driven by typed project properties. Prefer contextual panels or sheets on iPhone and persistent inspector on iPad.
7. **Keyframe/graph editor:** property-specific keyframe navigation, interpolation/easing controls and graph editing.
8. **Settings and asset/effect browsers:** compact, searchable, grouped interfaces with persistent settings and clear disabled/unsupported states.

### UI implementation constraints

- Produce a separate Vexel design system and component architecture; do not port the source app's Compose UI or copy its navigation hierarchy.
- Keep UI presentation separate from project state and engine behavior.
- SwiftUI views observe state and dispatch typed editing commands; they do not mutate a second copy of the project.
- Use reusable components and adaptive layouts, not one monolithic editor view.
- Keep the renderer and timeline independent of screen layout so the same engine supports iPhone and iPad.
- Create and review screen concepts/wireframes for home, preset creation, editor portrait, editor landscape, timeline/keyframe editing, and properties before implementing the full redesign.
- UI redesign must not block the canonical project/editing model work. Build the design system and screen shell against stable view models and command interfaces.

## 3. Current implementation status

### App and UI baseline

- [x] Universal SwiftUI app target configured for iPhone and iPad.
- [x] Onboarding, Projects, Presets, and Settings destinations exist.
- [x] Composition creation and editor workspace surfaces exist.
- [x] Existing AMOLED graphite and teal/cyan visual system exists.
- [x] Timeline, layer/tool panels, effect browser, properties, graph, composition settings, and export surfaces exist at varying levels of functionality.
- [ ] Existing UI is not the approved final design. A substantial Alight Motion-inspired, Vexel-original redesign is required.
- [ ] Full iPhone/iPad adaptive editor layout and landscape validation remain incomplete.

### Project model, persistence, and import

- [x] Native Vexel `.vexelproj` identity and v2 document format.
- [x] Native v1-to-v2 migration.
- [x] Typed native schema for composition, assets, markers, all 11 source layer discriminators, transforms, animation, keyframes, easing, effects, and recursive groups.
- [x] JSON-backed unknown-field preservation through nested structures.
- [x] Typed accessors for layer payloads, vectors, gradients, path points/tangents, cutout data, and seven effect parameter kinds.
- [x] App persistence bridge decodes typed native projects and validates typed round-trips before persistence.
- [x] Isolated legacy importer; Android format identifiers are import-only.
- [x] Structured unsupported-feature report and pre-import review UI.
- [x] Archive extraction byte budgets, traversal/duplicate/symlink/entry/size/compression-ratio defenses, staged import, rollback and failure-injection coverage.
- [x] Kotlin-generated Android v12 JSON fixture.
- [x] Test-assembled video/audio archive fixture with referenced MP4/M4A assets.
- [ ] Obtain a genuine archive exported by the Android reference app and compare archive entries, CRCs, metadata and referenced assets.
- [x] Finish effect-instance parameter value/range validation, including integer type enforcement.
- [x] Audit source semantic-validator rules against `ProjectValidator.kt` and port the remaining import-critical content, media-speed/source-in-point, EQ, 3D-text, layer-kind warning, and unsupported-expression checks. Expression syntax remains intentionally warning-only until a safe native expression evaluator exists.
- [ ] Confirm preservation and migration behavior against additional representative source fixtures.
- [ ] Complete persistent asset lifecycle, cleanup, recovery and full-document project duplication.

### Editing engine

- [x] Actor-owned `VexelEditingStore` foundation with typed commands, validation, history snapshots, coalescing and parent-cycle protection.
- [x] Primary layer add/duplicate/delete/split/group and effect-stack operations routed through the store.
- [x] Timeline move/trim commits and visibility/lock changes routed through the store.
- [x] Group/ungroup validation and timing/reference safeguards.
- [ ] Transform/property/keyframe, marker, media and composition-setting mutations routed through the store.
- [ ] Replace workspace-owned undo/redo snapshots with store-owned history as the sole authority.
- [ ] Eliminate the reduced timeline projection as an independent mutation authority; it may remain a presentation projection only.
- [ ] Complete multi-selection, reorder, snapping, ripple edits and nested group editing.
- [ ] Typed property descriptors, set-value and auto-keyframe behavior.
- [ ] Full keyframe clipboard/navigation, interpolation, cubic Bézier and cyclic easing, loop and ping-pong behavior.
- [ ] Constrained deterministic expression evaluation without unrestricted host access.

### Scene evaluation and rendering

- [x] Scene evaluator foundation for basic 2D transforms, hierarchy, shape/text data and partial keyframe sampling.
- [x] Metal device/command queue and render graph validation scaffolding.
- [x] Initial Metal shader functions for copy, brightness/contrast, Gaussian blur and multi-scale glow combination.
- [ ] Replace/extend the simplified evaluator with deterministic evaluation of the typed native project at a composition timestamp.
- [ ] Resolve nested timing, inherited transforms, animated properties, expressions and effect parameters.
- [ ] Model renderable 2D/3D content, cameras, lights, masks, mattes, transitions, blend modes and other source semantics.
- [ ] Implement actual Metal render-graph execution, resource lifetime/pooling, caching, compositing and color/alpha handling.
- [ ] Connect the same scene evaluator and renderer to interactive preview and export.
- [ ] Integrate shader translation and runtime shader loading with pinned toolchain, diagnostics, validation, caching and uniform mapping.
- [ ] Add deterministic scene tests and GPU image regression tests.

### Effects, media, audio, export

- [x] Source effect catalogue contains 73 effect IDs across 13 categories.
- [ ] Effect catalogue entries must be distinguished from executable effects; parameters and rendering are incomplete.
- [ ] Port and validate effects only after the render graph and parameter binding are ready.
- [ ] AVFoundation image/video/audio decoding, random-access seeking, frame cache and proxy workflow.
- [ ] Asset import, persistent storage, relinking and cleanup.
- [ ] Realtime preview audio and deterministic 48 kHz stereo mixing.
- [ ] Metal offscreen rendering and MP4 export through AVAssetWriter.
- [ ] Export progress, cancellation, codec/color-space validation and supported image/GIF sequence formats.
- [ ] Captions/SRT, stabilization, cutout, camera workflows and advanced 3D where supported.

## 4. Prioritized implementation plan

Priorities are dependency-based. Do not jump to effect parity or advanced media before project state, evaluation and rendering contracts are stable.

### P0: Close project integrity and establish a truthful baseline

- [x] Validate known effect-instance parameter types (including whole-number integer parameters), choices, point/stops shapes, finite numeric values and declared ranges against the canonical effect registry. Unknown effects/parameters are preserved and reported as warnings.
- [x] Extend source semantic parity for required layer payloads (reported as warnings for incomplete legacy imports), non-visual effects/masks, packed-alpha applicability, ambient-light shadow behavior, 3D text ranges, and text animator timing. Remaining type-specific rules are tracked as a bounded follow-up rather than silently assumed complete.
- [x] Generate a `.knsproj` archive using the reference repository's production Kotlin `KnsprojArchive.write()` implementation and verify the ZIP contents.
- [x] Test Vexel's importer against the generated source-writer archive; the dedicated cross-repository CI import job passed on commit `7ed70d4`.
- [ ] Optional provenance follow-up: obtain an archive exported by running the Android application itself. The source-writer fixture is production-serializer-generated and successfully imported, but is not an app-session export. This is not a blocker for the importer implementation.
- [x] Keep legacy import isolated; fixture tests cover unknown-field preservation through importer round trips.
- [x] Prove unknown-field preservation through the app document bridge after a metadata edit, including nested shape and layer extension fields; archive-level ZIP export/reopen coverage also verifies nested unknown fields.
- [x] Validate project asset references and expected asset types recursively; validate effect parameter instances before accepting an imported project.
- [x] Make project deletion save the updated library index before deleting its asset directory, so an index-write failure cannot leave a saved project pointing to deleted assets.
- [x] Make project duplication commit the copied asset directory and updated library index as one recoverable operation; roll back copied assets when index persistence fails.
- [x] Add an app XCTest target and failure-injection coverage for duplicate commit success, index-write failure rollback, rollback failure reporting, and bridge round-trip preservation. The duplicate transaction seam is covered; filesystem-level integration and delete cleanup failure remain explicit P1 hardening items.
- [x] Correct README and build/testing guides to describe the current separate CI and manual unsigned-IPA workflows.
- [x] Refresh the source audit, Android compatibility guide and porting roadmap to reflect persisted projects, connected import review, effect-aware validation and the current iOS-only development order.
- [x] Refresh PR #2 status text after final CI verification.
- [x] Disable automatic push and pull-request triggers for expensive workflows; iOS CI, source archive generation/import, and IPA packaging are now manual-dispatch only.
- [x] Keep CI green for package tests, XcodeGen generation and simulator build on commit `7ed70d4` (run `45364469639`).
- [x] Run the updated `xcodebuild test` workflow after the final P0 code changes. Run `45370528079` passed on code commit `2a80cc2`; the only subsequent commit (`c0b95f9`) restored manual-only workflow triggers. Package suites, app persistence XCTest target (4 tests), XcodeGen generation, simulator app tests and simulator build all passed.
- [ ] Optional: re-run unsigned IPA packaging on the current branch head. This is a packaging artifact check, not a blocker for P0 code integrity; the prior unsigned IPA run `45356750586` predates the final P0 code.
- [x] Maintain a clear distinction between successful CI, successful IPA packaging, signed installation and physical-device validation.

### P1: Canonical editing state, editor redesign, and deterministic scene evaluation

P1 is active. The canonical-store integration is progressing and must remain distinct from the still-open editor redesign and full scene-engine work. Do not mark P1 complete until all three tracks are implemented and verified.

**P1.1 Canonical editing authority**
- [x] Establish `VexelEditingStore` as the owner of the typed `VexelNativeProject` snapshot and undo/redo history.
- [x] Remove duplicate workspace undo/redo stacks.
- [x] Keep composition-settings and timeline edits in local drafts; commit changes through the store.
- [x] Route project rename, composition settings, timeline edits, marker edits, media registration, visibility/lock, duplicate/delete/split/group and effect operations through store commits.
- [x] Serialize store snapshots back to the project library after successful commands.
- [x] Add command tests for invalid-operation atomicity, undo/redo, coalescing, nested operations, grouping, effect parameters and snapshot replacement.
- [ ] Replace generic snapshot-replacement commits with dedicated typed commands for marker and keyframe mutations.
- [ ] Connect transform/property inspector controls to typed store commands and verify every remaining edit surface.

**P1.2 Alight Motion-inspired Vexel UI redesign**
- [x] Establish the original graphite/teal Vexel visual foundation, palette, adaptive surfaces and motion tokens.
- [ ] Redesign home/projects and preset creation screens as a cohesive editing product.
- [ ] Complete the editor redesign around preview, timeline, layer selection, contextual tools and property editing.
- [ ] Validate portrait iPhone and landscape/iPad adaptive layouts.
- [ ] Finish reusable timeline, clip, track, playhead, keyframe, tool dock and inspector components.
- [ ] Bind every implemented control to the canonical store and expose incomplete capabilities honestly.
- [ ] Add UI tests for navigation, selection, timeline gestures, accessibility and state restoration.

**P1.3 Animation and deterministic scene model**
- [x] Establish a deterministic `FrameScene` contract from a native project document and composition time.
- [x] Implement baseline keyframe interpolation, easing presets, cycle/ping-pong sampling and nested group timing/transforms.
- [x] Add deterministic scene-evaluation regression tests for interpolation, loop modes and nested groups.
- [ ] Implement typed property animation and constrained expressions.
- [ ] Complete nested compositions, 2D/3D transforms, camera/light state, masks, mattes, transitions and evaluated effect parameters.
- [ ] Add golden coverage for representative source projects and broader time samples.

### P2: Metal renderer and executable effects

- [ ] Implement render-graph execution, resource pooling, caching, pass scheduling and compositing.
- [ ] Implement shape, text, image and video rendering.
- [ ] Add 3D geometry/material, camera, lighting, depth-of-field and environment rendering.
- [ ] Implement blend modes, masks, mattes, transitions, motion blur, shadows and time-slice effects.
- [ ] Integrate shader compilation/translation and runtime diagnostics.
- [ ] Port effects incrementally, validate parameter defaults/ranges and compare output against source reference frames.
- [ ] Add GPU image regression tests, memory limits and performance budgets on supported iPhones and iPads.

### P3: Media, audio, and export

- [ ] Complete media import and persistent asset lifecycle.
- [ ] Implement AVFoundation decoding, proxy generation, waveform extraction, frame caching and seeking.
- [ ] Implement synchronized preview audio and deterministic 48 kHz stereo mixing.
- [ ] Implement shared preview/export scene evaluation and Metal rendering.
- [ ] Implement AVAssetWriter MP4 export with progress, cancellation and codec/color-space validation.
- [ ] Add captions/SRT and supported image/GIF sequence export.

### P4: Advanced features, hardening, and release

- [ ] Advanced 3D/model workflows, stabilization, cutout and other features after core renderer readiness.
- [ ] Plugin installation, permissions, sandboxing and license browser.
- [ ] Full autosave, crash recovery, snapshots, project duplication and asset cleanup.
- [ ] Localization, font management, settings persistence and accessibility.
- [ ] iPhone/iPad real-device performance, memory, battery, thermal, orientation and multitasking validation.
- [ ] GPL-3.0 and third-party dependency license review before distribution.
- [ ] Signing, provisioning, installation and release pipeline.

## 5. Known limitations (do not misreport)

- The timeline remains a reduced UI projection over the canonical typed native project. Some edits still use validated snapshot replacement rather than dedicated typed commands.
- The workspace now delegates undo/redo and committed mutations to `VexelEditingStore`; transform/property inspector controls and several advanced editing surfaces remain unconnected.
- The scene evaluator is deterministic for the currently supported 2D baseline, keyframe interpolation, easing, loop modes and nested groups. It is not equivalent to the source scene evaluator and does not yet implement full 3D, camera/light, masks/mattes, transitions or evaluated effect parameters.
- The Metal renderer and shader compiler remain foundations; a complete render graph is not executing yet.
- The effect catalogue is not proof that 73 effects execute.
- Playback currently advances the playhead; full animated scene rendering and synchronized audio playback are not established.
- Imported project data can preserve unsupported fields, but not every source feature is editable or renderable.
- The current source archive is generated by the reference repository's production Kotlin serializer and archive writer using checked-in project/media assets; it is not captured from an Android app session.
- A successful unsigned IPA build does not mean the IPA is signed, installable, or tested on a physical device.
- GPL-3.0 and third-party dependency obligations require review before distribution.

## 6. Verification record (2026-11-24)

Current feature branch head before this task-status update: `ac41257edac9e3e2544e04a9b7feec3559e10403`. P1 CI run `45374010309` is testing the workspace/store integration and scene-evaluation tests; its final result must be recorded before IPA packaging.

- [x] iOS CI run #35, run ID `45355757013`: successful. The job log reports 243 tests with zero failures, package/build validation and simulator-target build.
- [x] IPA workflow run #574, run ID `45356750586`: successful. Xcode archive, unsigned IPA packaging, ZIP integrity check and artifact upload completed.
- [x] IPA artifact: `Vexel-unsigned-IPA`; includes `Vexel-unsigned.ipa` and SHA-256 checksum. Artifact is available from the workflow run.
- [ ] Signed installation on a physical iPhone/iPad has not been verified in this record.
- [ ] Runtime interaction, rendering, media, audio and export behavior have not been validated on a physical device.
- [ ] Do not reuse historical verification claims for a newer commit without checking its workflow runs.

Successful workflow references:
- Latest successful CI: https://github.com/IamAizen17/vexel-ios-/actions/runs/45364469639
- Source-writer archive and Vexel import: https://github.com/IamAizen17/vexel-ios-/actions/runs/45364456096
- [x] Final P0 regression run `45370528079` passed on `2a80cc2ed58d5d3533c017375e07e0d3aa629265`: archive/import (32 tests, 1 skipped), core (54), renderer (3), shader compiler (5), and app persistence/bridge XCTest (4), all with zero failures. XcodeGen project generation and iPhone simulator app test/build step also passed (`** TEST SUCCEEDED **`). The branch's current `c0b95f9` commit only restores manual-only CI triggers and does not change tested source code.
- IPA: https://github.com/IamAizen17/vexel-ios-/actions/runs/45356750586

## 7. Required engineering workflow

1. Fetch the latest branch head and inspect the relevant files before editing.
2. Preserve unrelated user changes and public interfaces unless a migration is intentional and documented.
3. Compare source behavior with source code and fixtures; do not infer implementation details from UI appearance alone.
4. Make small, dependency-ordered changes with tests.
5. Run formatting, package tests, XcodeGen, simulator build and IPA archive where applicable.
6. Inspect the diff and verify the exact branch and commit before reporting.
7. Update this file whenever priorities, implementation status, or verification results materially change.
8. Report what changed, files affected, checks performed, and remaining gaps. Never claim a test, build, device check or feature succeeded unless evidence confirms it.
