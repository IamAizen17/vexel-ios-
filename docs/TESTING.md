# Vexel Testing Strategy

## Unit tests
Project defaults, IDs, timeline math, keyframe interpolation, easing, transforms, expression evaluation, parenting, undo/redo, migrations and validation.

## Archive and compatibility
Test valid/malformed ZIPs, traversal, duplicate normalized paths, symlinks, ZIP bombs, missing/duplicate/corrupt assets, every supported .knsproj version, .vexelproj semantic round trips and unknown-field preservation.

## Scene evaluation
Use deterministic fixtures with expected evaluated nodes at exact timestamps. Cover nested groups, parent transforms, layer timing boundaries, mattes, masks, camera/light evaluation, effects and temporal sampling.

## Rendering
Use fixed assets and reference frames with documented tolerances. Test alpha premultiplication, color conversion, blend modes, masks, effect parameters, resolution scaling and Metal resource recreation.

## Media
Test variable frame-rate inputs, rotation metadata, missing tracks, A/V sync, sample-rate conversion, channel layouts, decode failures, cancellation and export finalization.

## UI
Test open/save, import/relink, timeline gestures, inspector edits, orientation/size-class transitions, iPhone/iPad navigation, keyboard/trackpad actions and accessibility identifiers.

## Performance
Track memory, GPU/CPU time, frame pacing, dropped preview frames, cache growth, export throughput, thermal state and background/foreground recovery. Include the oldest supported device.

## Golden fixture record
Each fixture records reference commit, original format/version, input hashes, timestamp/frame, expected scene or image, tolerance and evidence class (source-derived, test-derived or runtime-confirmed). Do not include copyrighted assets without distribution rights; synthetic assets are preferred.

## CI gates
Swift format/lint, package resolution, unit tests, archive security, compatibility fixtures, iPhone/iPad simulator builds, Metal shader compilation and stable UI tests. Device-only GPU, codec, memory and thermal behavior must be tested on real hardware.

A simulator build does not establish real-device performance or export correctness.
