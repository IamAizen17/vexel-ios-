# Android reference archive fixture

This fixture is based on the Android reference repository at commit `0fe341060cec9710df90bc1ba7fda85006c188d8`.

The document is copied byte-for-byte from:

`.claude/skills/knsproj/examples/basicos/video-audio/project.json`

The referenced assets are copied byte-for-byte from:

- `assets/clip.mp4` (73,048 bytes; source Git blob `b534b782b33003da109ab2343f5a1c5cb7229183`)
- `assets/music.m4a` (38,439 bytes; source Git blob `db04050444908ec5e41bb0b163c25a65026f33bd`)

The ZIP contains `project.json`, `assets/clip.mp4`, and `assets/music.m4a`, matching the entry layout documented and written by Android `KnsprojArchive.kt`.

The archive was assembled as a deterministic test fixture from the Android repository's sample document and asset blobs. It was not exported by running the Android application. Keep this distinction explicit; a direct Android-app-exported `.knsproj` remains a required interoperability fixture.
