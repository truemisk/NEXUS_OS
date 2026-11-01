# CHANGELOG — NEXUS OS

## v0.6.4 — GitHub Update Center (2026-11-01)

- Added GitHub stable feed using `update.nxs` and pinned `raw.githubusercontent.com/truemisk/NEXUS_OS` URL.
- Added `CHECK GITHUB UPDATES` and `DOWNLOAD GITHUB RELEASE` UI actions.
- Added bundled pure Lua 5.3 SHA-256 (Data Card not required), with streaming verification.
- Validate channel, version, URL, release size, Lua syntax and SHA-256 before staging.
- Recalculate staged GitHub file checksum before installation; fail closed on mismatch.
- Reuse existing user-confirmed backup, trial launch, rollback and `/home/osv4.lua` autostart.
- Keep legacy Pastebin ID downloading as a fallback. Never auto-install downloaded releases.
- Added `tools/write_update_manifest.py`, matching `update.nxs`, `update.json`, `SHA256SUMS`.
- Added GitHub updater core and UI simulation tests.
- GitHub updates remain **unverified on real Minecraft hardware** until user tests.

## v0.6.2 — Phase 5B repair

- Improved legacy downloader diagnostics, trial finalization and component enumeration.

Earlier version histories and reports remain in `docs/`.
