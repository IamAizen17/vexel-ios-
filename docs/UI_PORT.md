# Reference UI port

## Source baseline

- Repository: https://github.com/IamAizen17/vexel-editor
- Audited source commit: `0fe341060cec9710df90bc1ba7fda85006c188d8`
- Source license: GPL-3.0
- Port target: native SwiftUI, universal iPhone and iPad
- Port date: 2026-11-23

The Android app flow was traced from `MainActivity.kt`, `HomeScreen.kt`, `EditorScreen.kt`, the editor chrome and panels, onboarding, settings, and plugin UI. The SwiftUI port preserves the major navigation destinations and tool categories while using native iOS presentation and adaptive layouts.

## Screen and page inventory

| Reference area | iOS implementation | Status |
|---|---|---|
| Onboarding | `VexelOnboardingView` | Implemented |
| Home / projects | `VexelHomeView` | Implemented |
| Project creation dialog | `NewProjectSheet` | Implemented |
| Project presets | Presets destination | Implemented |
| Project import entry | Files importer | UI wired; parser pending |
| Project duplicate / delete | Project cards and menu | Local UI state |
| Settings | `VexelSettingsPage` | Implemented |
| Plugin manager | `VexelPluginsPage` | UI implemented; installer pending |
| Editor top bar | `VexelEditorWorkspace` | Implemented |
| Preview / viewport | Preview canvas placeholder | UI only; renderer pending |
| Playback transport | Editor transport bar | UI state only |
| Timeline ruler and tracks | Timeline panel | UI state only |
| Layer list and actions | Layers tool sheet | UI state only |
| Selection actions | Selection bar | UI state only |
| Properties inspector | Transform, Style, Content, Effects, Masks, Layer | UI implemented; command binding pending |
| Graph editor | `VexelGraphEditor` | UI implemented; keyframe binding pending |
| Curve editor | `VexelCurveEditor` | UI implemented; easing binding pending |
| Shapes | 2D and 3D shape sheets | UI implemented |
| Text | Text and 3D text tools | UI implemented |
| Media | Image/video/font import entry | Partial; asset pipeline pending |
| 3D | Primitive and scene-object tools | UI implemented |
| Effects | Search, 13 categories, 73 effect entries, parameter detail sheet | UI implemented; renderer and parameter schema binding pending |
| Motion | Keyframe, graph, curve and expression entry | UI implemented |
| Audio | Mixer, audio import and processing controls | UI implemented; audio engine pending |
| Camera | Virtual camera controls | UI implemented; scene camera pending |
| Captions | Caption track, SRT and speech workflow entry | UI implemented |
| Elements | Saved-elements manager | UI implemented; persistence pending |
| Plugins | Extension manager and package import entry | UI implemented; plugin runtime pending |
| Export | Format, resolution, frame rate and quality | UI implemented; renderer/export pipeline pending |
| Effect detail | Effect preview, enabled state, amount, radius, blend mode | UI implemented; real effect parameters pending |
| Text to speech | Voice, speed, pitch, format, text editor | UI implemented; model/runtime pending |
| Marker editor | Marker name, time and color | UI implemented; timeline marker model pending |
| Stabilization dialog | Method, smoothing, crop, rolling shutter | UI implemented; motion analysis pending |
| Media job dialog | Progress, cancel and status | UI implemented; background job manager pending |
| Composition settings | Size, frame rate, duration and title | UI implemented |

## Important implementation boundary

This milestone ports the UI structure and visible control surfaces only. Controls that require project mutation, animation evaluation, GPU rendering, media decoding, audio mixing, plugin execution, or export are intentionally not represented as completed engine features. Those will be connected in the later engine port.

The project library starts empty, matching a first-launch editor. The UI uses local demonstration state for preview layers, timeline selection, transport position, marker controls, and sample properties. Project archive import/export, rendering, and engine-backed edits are not reported as complete.

## Adaptive behavior

- iPhone uses a compact, preview-first editor with a persistent timeline and a horizontally scrollable tool shelf.
- iPad uses a wider editor layout with a persistent properties inspector beside the preview and timeline.
- Both layouts use the same SwiftUI screens and state model.
