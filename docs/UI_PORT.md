# Reference UI port and comparison

## Audit baseline

- Reference repository: https://github.com/IamAizen17/vexel-editor
- Pinned source revision: 0fe341060cec9710df90bc1ba7fda85006c188d8
- Destination branch: feat/port-reference-ui
- Platform: universal iPhone and iPad
- UI framework: SwiftUI
- Source license: GPL-3.0; see LICENSE and NOTICE.md

The Vexel UI is an original native redesign, not a pixel-for-pixel Compose recreation. The comparison criterion is screen coverage, interaction intent, information architecture and feature affordances. The engine behavior is not considered ported because a control exists. The design system now uses an AMOLED graphite base with teal accents rather than the earlier purple palette.

## Navigation and home

| Reference source | SwiftUI destination | Comparison |
|---|---|---|
| MainActivity onboarding gate | VexelRootView | Covered |
| Onboarding.kt | VexelOnboardingView | Four pages, skip, language and theme selection now represented. Language selection is stored; full localization is pending. |
| HomeScreen.kt / HomeNav | VexelHomeView | Projects, presets and settings tabs covered with redesigned navigation. |
| ProjectsTab / ProjectCard | projectsPage / ProjectCard | Create, open, duplicate, delete and export entry points represented. Project data is still in-memory; persistence and real archive operations pending. |
| ProjectStore import/export | Files importer and project menu | UI entry points exist. No project is imported/exported until the archive adapter is implemented. |
| PresetsTab / NewProjectDialog | presetsPage / NewProjectSheet | Canvas presets and composition setup represented. Confirm exact source preset dimensions/labels before parity sign-off. |
| Recovery, import errors and warnings | Home alert state | Not yet ported. |
| PluginInstaller / PluginsScreen | VexelPluginsPage | Page shell exists; current list is sample data and package validation/install is pending. |

## Editor workspace and tools

| Reference source | SwiftUI destination | Comparison |
|---|---|---|
| EditorScreen / EditorTopBar | VexelEditorWorkspace editorHeader | Main header, composition settings, rename and export entry points represented. |
| Viewport / ViewModePill | previewCanvas and camera controls | Preview surface and inspector layout represented; actual viewport, gestures, gizmos, camera modes and rendering are pending. |
| EditorControls | transportBar | Transport and time controls represented with local state; undo/redo and frame stepping are not connected to commands. |
| Timeline.kt | VexelTimelinePanel / VexelTimelineTrackRow | Native scrollable ruler, playhead, pinch zoom range (8...2000 px/s), frame/snap-point alignment, composition-time nested group offsets, marker flags/editing, clip move/trim gestures, visibility/lock and keyframe affordances. Missing: focus-preserving pinch anchor, playhead auto-follow during playback, populated keyframe data and PCM waveform. Track edits are local project state, not engine commands. |
| LayersPanel / AddSheet | Layers, Shapes, Text, Media and 3D tool pages | Main layer and creation categories represented. Layer-tree hierarchy, typed layer creation and asset-backed imports are pending. |
| SelectionActions | selectionBar | Common selection actions represented; split, group, keyframe and delete must be command-backed. |
| PropertiesPanel.kt | VexelPropertiesPanel / VexelPropertiesSheet | Source tab structure is now represented: Transform for all layers, Text for text layers, Effects/Transitions for visual layers, Masks for 2D visual layers. Common 2D transform, layer settings, text, effect, mask/matte and transition control groups are visible. Remaining: dynamic LayerProps rows for every layer type, complete text/3D/media content controls, gradients/stops editing, effect-stack reorder and real mutation commands. All inspector values remain local UI state. |
| GraphEditor.kt | VexelGraphEditor | Graph editor surface exists; source tangent handles and keyframe editing semantics are not yet parity-tested. |
| Curve editor in Panels.kt | VexelCurveEditor | Curve surface exists; saved easing persistence and exact source curve operations pending. |
| AddEffectSheet.kt / EffectRegistry | effectsPage / VexelEffectCatalog / VexelEffectDetailSheet | Bundles the pinned generated source registry (73 IDs, 13 categories, typed parameter defaults/ranges/choices). Category-grid and search flow are ported; effect target is the selected timeline track; 3D-only effects are disabled on non-rendered-3D tracks; shortcuts are category-scoped and disabled for incompatible track kinds. Detail controls are generated for number, integer, boolean, choice, color, point and gradient stops. Effect insertion, animated parameter serialization and rendering remain pending. |
| AudioUi.kt | VexelAudioWorkspace | Mixer/EQ UI shell exists. Source audio clip controls, automation and realtime audio are pending. |
| CaptionsUi.kt | VexelCaptionWorkspace | Caption list and styling shell exists. SRT parsing, speech alignment and project binding pending. |
| ExpressionUi.kt | VexelExpressionWorkspace | Expression editor shell exists. Source language API, syntax validation, execution and error mapping pending. |
| PluginsSheet.kt | Plugins tool page / VexelTextToSpeechWorkspace | TTS and preset-related UI entry points represented. Installed command discovery, preset application and safe plugin host pending. |
| ElementsSheet.kt | Elements tool page | Saved-element UI shell exists; source element serialization, insert/apply behavior and persistence pending. |
| CutoutBrushUi.kt | VexelCutoutBrushWorkspace | Brush controls and frame navigation shell exist; paint canvas, stroke history and propagation are not implemented. |
| MediaJobUi.kt | VexelStabilizationSheet / VexelMediaJobSheet | Progress and settings shells exist; worker jobs and cancellation are pending. |
| RealCameraUi.kt / RealCameraController.kt | VexelRealCameraWorkspace | Settings controls now represented (axes, intensity, smoothing, simplification, tolerance, calibration and position). Sensor capture, countdown, recording overlay, review, retry, accept and discard are pending. VexelCameraWorkspace remains the separate virtual scene camera panel. |
| ExportDialog | VexelExportSheet | Format and output settings represented; render queue, progress, cancellation, file writing and codec capability checks pending. |
| SavedVersions in PropertiesPanel.kt | VexelSavedVersionsSheet | Empty-state page and navigation exist. Snapshot listing, creation, restore and history integration are pending. |

## Settings comparison

| Reference setting | Vexel UI | Status |
|---|---|---|
| Theme: dark/light/system | Appearance picker | UI + preference storage |
| Language: system/English/Portuguese | Language picker | UI + preference storage; localization pending |
| Preview resolution/scale | Preview scale | UI + preference storage; exact source values 100%, 50%, 25% now match. |
| 3D preview quality | Quality selector | UI + preference storage |
| Video proxies | Toggle | UI + preference storage; proxy pipeline pending |
| Auto keyframe | Toggle | UI + preference storage; engine binding pending |
| Show layer names | Toggle | UI + preference storage; timeline binding pending |
| Mirror project to Files | Toggle | UI + preference storage; file mirroring pending |
| Snapshot safety/recovery | Snapshot toggle | UI + preference storage; snapshot engine pending |
| Font information/management | Partial | Dedicated font manager/import UI pending |
| Third-party licenses | Attribution summary | Full license browser pending |
| App version/project format | About information | Partial |
| Plugin manager | Plugin entry | Page shell; installer/runtime pending |

## UI-only boundary and known misleading behavior removed

- Project import no longer inserts a fake project after a file is selected.
- Image/video/audio selection no longer inserts fake media layers. The UI reports that ingestion is pending.
- Effect shortcut actions report the missing engine integration instead of claiming a mask, matte, transition or text animator was applied.
- Shape/text/layer controls still use local presentation state in places. They are not persistent project mutations and must be replaced with typed engine commands.

## Sign-off requirements

The UI milestone is not complete until:
1. Every source screen and modal has a named SwiftUI counterpart or a documented intentional redesign/removal.
2. Every visible control has a real action, is disabled, or clearly communicates that its engine integration is pending.
3. iPhone portrait, iPhone landscape and iPad layouts are checked independently.
4. Navigation, sheets, dismissal, accessibility labels, keyboard focus and Dynamic Type are checked.
5. The generated iOS app builds and UI smoke tests cover every route.
