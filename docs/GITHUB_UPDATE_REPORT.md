# Phase 5C (GitHub Update Center) — v0.6.4 completion report

Date: 2026-11-01

## Implemented

- Stable GitHub Raw feed pinned to the NEXUS repository.
- Manual version check and download buttons inside Update Center.
- Strict, size-bounded `update.nxs` parser; trust boundary against URLs outside the repository.
- Pure Lua 5.3 streaming SHA-256, validating downloaded candidate before staging and again before installation.
- OpenOS `wget` primary transport, callable-iterator Internet API fallback.
- Existing manual install confirmation, previous.lua backup, transaction marker, rollback and autostart unchanged.
- Retained legacy pastebin.com ID input for compatibility.

## Verification

- 145 PASS lines from all Lua 5.3 local regression, mock-hardware, mock-network and GUI checks.
- Existing single-file bundle boots/exits in simulated OpenOS environment.
- SHA-256 known vectors including 1 million `a` bytes verified.
- Manifest SHA and file-size checks match `dist/nexus.lua`.
- Tested checksum mismatch, mutated staged file and denied auto-install.

## Still requires real Minecraft confirmation

- First v0.6.2 -> v0.6.4 upgrade using OpenOS staged.lua + Update Center.
- Fetch of `update.nxs` from within running NEXUS.
- End-to-end SHA-256 verified in-app upgrade when a *future* version appears.
- Performance and responsiveness of SHA-256 on the actual OpenComputers CPU.
- Recovery from real, unexpected shutdown during upgrade.

## Caveats

- SHA-256 + manifest is not an authenticated signature. Repo write access remains a critical trust boundary.
- OpenOS `wget` is not streaming-limited; downloads are size checked immediately after it returns, before staging.
- No EEPROM, firmware, bootloader or OpenOS kernel modifications.
