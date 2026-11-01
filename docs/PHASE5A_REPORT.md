# Phase 5A report

## Implementation

Added `nexus.core.update` and `nexus.core.startup`, plus `nexus.apps.updatecenter`; retained all Phase 4 applications and recovery/display handling. The new single-file wrapper owns staged-update promotion and relaunch only *after* the GUI returns and the GPU is restored.

### Update protocol

- Accept only a user-supplied 6–16-character alphanumeric Pastebin ID, download over HTTPS via OpenOS `internet.request` into `/home/nexus/updates/download.part`.
- Stream with a 300,000-byte bound; reject empty results and malformed content.
- Candidate must contain distribution/version headers, have a strictly greater three-number version, and compile with `loadfile(path,'t')` before install; these checks are not cryptographic authentication.
- Stage in `/home/nexus/updates/staged.lua`, not the live core.
- After explicit confirmation: exit GUI, restore GPU, move current `/home/osv4.lua` into `previous.lua`, create trial marker, move stage into the stable path and call the new version.
- If trial errors or a later startup detects a transaction marker, attempt rollback. A normal clean return from the trial clears the marker; backup remains available for later manual rollback.
- A small time window between file renames cannot be fully atomic across power loss; retain manual old-code copy and independent recovery helper.

### Autostart

- Opt-in from Update Center (two-step confirmation) or standalone Maintenance CLI (`enable YES`).
- Edits only the marked NEXUS stanza in `/home/.shrc`, retains `.shrc.nexus-prev` and unrelated content; known v0.4.0 stanza can be migrated.
- Stable bootstrap `/home/nexus-boot.lua` uses `/home/osv4.lua`; no EEPROM/BIOS/boot loader changes.
- Guard on failed launch skips future automatic starts; recovery is explicit. Bootstrap detects interrupted upgrade markers and attempts rollback prior to launch.

## Validation

- Phase 3 regression: 42 passed.
- Phase 4 regression: 29 passed.
- New Phase 5A functional tests: 12 passed.
- GUI rendering/navigation (including compact size): 2 passed.
- Full v0.5.1 release fixture tests, startup Lua syntax and CLI: 5 passed.
- Bundled v0.5.0 smoke: 1 passed.
- **Total: 91 local checks** across the above suites. No live in-game Phase 5A test yet.

## Out of scope

- Automatic polling/version discovery, signed update manifests, hardware automation/VAULT, standalone BIOS, and floppy installer. Future versions must preserve `NEXUS-DISTRIBUTION: 1` and increment the semantic version for in-GUI updates.
