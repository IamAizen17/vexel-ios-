# Android reference archive fixture

This fixture is based on the Android reference repository at commit `0fe341060cec9710df90bc1ba7fda85006c188d8`.

The document is copied byte-for-byte from:

`.claude/skills/knsproj/examples/basicos/video-audio/project.json`

The referenced assets are copied byte-for-byte from:

- `assets/clip.mp4` (73,048 bytes; source Git blob `b534b782b33003da109ab2343f5a1c5cb7229183`)
- `assets/music.m4a` (38,439 bytes; source Git blob `db04050444908ec5e41bb0b163c25a65026f33bd`)

The ZIP contains `project.json`, `assets/clip.mp4`, and `assets/music.m4a`, matching the entry layout documented and written by Android `KnsprojArchive.kt`.

The archive generator workflow runs a focused Kotlin test against the reference repository and calls its production `KnsprojArchive.write()` implementation to create `kinesis-video-audio.knsproj`. The test reads the generated archive back with `KnsprojArchive.read()`, validates the project and verifies that both media assets survive byte-for-byte. This is stronger than hand-assembling a ZIP, but it is still generated from a checked-in sample and is not captured from an Android app session. A direct Android-app-exported `.knsproj` remains the final provenance fixture.
