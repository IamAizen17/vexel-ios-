# Licensing and Attribution Audit

## Reference license
The inspected IamAizen17/vexel-editor repository contains a GNU General Public License version 3 license file. Its Rust crate declares GPL-3.0-only.

A port that copies, modifies or creates a derivative work from GPL-covered source must be planned around the applicable GPL obligations. Changing Kotlin to Swift or replacing Android APIs does not automatically remove derivative-work obligations.

## UI port decision
The SwiftUI screen structure and visible UI behavior are adapted from the reference Android Compose UI. This is a derivative adaptation, not a clean-room implementation. The destination repository now includes the GPL-3.0 license text, a provenance notice, and a UI inventory. The port is being distributed under GPL-3.0. See the root `LICENSE`, `NOTICE.md`, and `docs/UI_PORT.md`.

## Release gate
Before distributing Vexel:
- Determine which code is copied, translated, adapted or independently reimplemented.
- Retain required copyright and license notices.
- Provide corresponding source and build/install information as required by the applicable GPL version.
- Audit dependencies, shaders, models, fonts, sample projects and media independently.
- Check compatibility of distribution channels and platform terms with the chosen license obligations.
- Obtain qualified legal review for the intended App Store and direct-distribution model.

This is an engineering checklist, not legal advice.

## Provenance
For each implementation area, record whether it is directly ported from GPL source, independently implemented from public format/behavior specifications, based on a third-party dependency, or based on user-owned assets/models. Never call a direct translation clean-room. Preserve provenance and required notices.
