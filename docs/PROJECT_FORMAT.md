# Vexel Project Format

## Identity

- Extension: `.vexelproj`
- Container: ZIP
- MIME type: `application/vnd.vexel.project+zip`
- Native document entry: `vexel.json`
- Format identifier: `vexelproj`
- Initial format version: 1

The MIME type and extension are Vexel-owned identifiers and are registered in the XcodeGen project configuration as the app's exported document type.

## Native package layout

```
Example.vexelproj
├── vexel.json
├── metadata.json
├── thumbnail.png
└── assets/
    ├── images/
    ├── videos/
    ├── audio/
    ├── fonts/
    └── models/
```

Only `vexel.json` is mandatory. Metadata and thumbnail are optional. Asset paths in the document are authoritative.

## Root document envelope

```json
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
```

This is the native envelope, not the complete schema. Field-level contracts are defined by VexelCore and versioned migrations.

## Import compatibility

- Native Vexel documents use `vexel.json` and `.vexelproj`.
- The importer recognizes the previous Android archive layout, whose root document is `project.json`, only at the import boundary.
- `VexelProjectImporter` translates the legacy format/version envelope into the current Vexel envelope. The legacy identifier is not accepted by VexelCore and cannot be written by the native archive exporter.
- Imported unknown fields are retained where possible. Unsupported features must be reported rather than silently discarded.
- All saves and exports use the native Vexel format.
- The current adapter performs envelope migration only. Full layer, effect, animation, and media semantic parity requires source fixtures and dedicated migration tests.

## Archive security

- Reject absolute paths, traversal, drive prefixes, alternate separators and duplicate normalized paths.
- Reject symlinks and unsupported entry types.
- Enforce entry count, per-entry size, total uncompressed size and document JSON size limits.
- Enforce decompression-ratio/resource budgets against ZIP bombs.
- Verify CRC and optional SHA-256 hashes.
- Never extract into shared/user-visible directories directly.
- Extract into unique staging storage and atomically promote only after validation.
- Do not trust MIME types/extensions; inspect media before decoding.
- Handle duplicate asset IDs and missing paths deterministically.

Current archive limits: document JSON up to 64 MiB, aggregate uncompressed data up to 8 GiB and 10,000 entries. Vexel may choose stricter device-specific limits but must not weaken validation without tests and rationale.

## Determinism

- Use stable JSON and numeric conventions where practical.
- Store project time in seconds and use an explicit rational frame timebase for frame operations.
- Asset identity must not depend on local absolute paths.
- Save/reopen must preserve semantic project equality.
- Migrations are pure transformations with fixtures for every supported version.

## Versioning

A migration registry maps (format, formatVersion) to the current internal model. Reject newer unsupported versions with an actionable error. Never decode them as an older schema.
