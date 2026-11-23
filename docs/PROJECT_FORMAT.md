# Vexel Project Format

## Identity
- Extension: .vexelproj
- Container: ZIP
- Proposed MIME: application/vnd.vexel.project+zip
- Root document: project.json
- Format identifier: vexelproj
- Initial format version: 1

The MIME type is a proposed identifier and must be used consistently in document type registration and export metadata.

## Package layout
~~~
Example.vexelproj
├── project.json
├── metadata.json
├── thumbnail.jpg
└── assets/
    ├── images/
    ├── videos/
    ├── audio/
    ├── fonts/
    └── models/
~~~

Only project.json is mandatory. Metadata and thumbnail are optional. Asset paths in JSON are authoritative.

## Root document envelope
~~~
{
  "format": "vexelproj",
  "formatVersion": 1,
  "generator": "Vexel",
  "meta": {},
  "composition": {},
  "assets": [],
  "markers": [],
  "editorView": {},
  "layers": []
}
~~~

This is an envelope example, not the complete schema. Field-level contracts must be derived from the reference schema and models before version 1 is frozen.

## Compatibility
- Import legacy Android project archives through a dedicated, isolated adapter.
- Convert imported data into the canonical Vexel project model.
- Preserve unknown fields in extension storage where possible.
- Do not silently discard unsupported effects, layers, parameters or metadata.
- Report features that cannot yet be rendered or edited.
- Save and export only as `.vexelproj` using Vexel's independent version number.
- Do not export to the legacy Android format. Legacy compatibility is import-only; users save and share native `.vexelproj` documents.

## Archive security
- Reject absolute paths, traversal, drive prefixes, alternate separators and duplicate normalized paths.
- Reject symlinks and unsupported entry types.
- Enforce entry count, per-entry size, total uncompressed size and JSON size limits.
- Enforce decompression-ratio/resource budgets against ZIP bombs.
- Verify CRC and optional SHA-256 hashes.
- Never extract into shared/user-visible directories directly.
- Extract into unique staging storage and atomically promote only after validation.
- Do not trust MIME types/extensions; inspect media before decoding.
- Handle duplicate asset IDs and missing paths deterministically.

Reference archive limits observed: JSON up to 64 MiB, aggregate uncompressed data up to 8 GiB and 10,000 entries. Vexel may choose stricter device-specific limits but must not weaken validation without tests and rationale.

## Determinism
- Use stable JSON and numeric conventions where practical.
- Store project time in seconds and use an explicit rational frame timebase for frame operations.
- Asset identity must not depend on local absolute paths.
- Save/reopen must preserve semantic project equality.
- Migrations are pure transformations with fixtures for every supported version.

## Versioning
A migration registry maps (format, formatVersion) to the current internal model. Reject newer unsupported versions with an actionable error. Never decode them as an older schema.
