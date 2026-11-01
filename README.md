# NEXUS OS

NEXUS OS is a lightweight graphical operating environment for **Minecraft OpenComputers**, running on top of OpenOS (Lua 5.3). It does not replace the BIOS, EEPROM, or OpenOS kernel.

## Current stable release: v0.6.5 — End-to-end updater test

NEXUS v0.6.5 is a **test-only maintenance release** of the working v0.6.4 GitHub Update Center. It intentionally introduces no new user features; the version bump allows verifying GitHub download, SHA-256 staging, manual installation, automatic relaunch and rollback on real OpenComputers hardware. The existing trial launch, backups, rollback, and opt-in autostart remain intact.

- **[OpenOS-ready bundle](dist/nexus.lua)** — intended for `/home/osv4.lua`
- **[Croatian installation and test guide](docs/GITHUB_UPDATE_v0.6.5_HR.md)**
- **[Stable update manifest](update.nxs)** — strict key/value format for OpenOS
- **[JSON release metadata](update.json)** — for external tools

## Main features

Graphical desktop with Cyan, CRT Green and Amber themes; File Manager, Terminal, System Monitor, System Center, Settings, Notifications, Update Center and Hardware Center. Hardware automation remains opt-in. VAULT Storage is not yet integrated. Navigation does not require the Minecraft-reserved ESC/F1–F12 keys.

### GitHub Update Center

Select `Update Center` → `CHECK GITHUB UPDATES` → `DOWNLOAD GITHUB RELEASE` → `INSTALL STAGED RELEASE`, confirming the installation. The stable feed is pinned to:

- `https://raw.githubusercontent.com/truemisk/NEXUS_OS/main/update.nxs`
- `https://raw.githubusercontent.com/truemisk/NEXUS_OS/main/dist/nexus.lua`

The updater validates channel, version, URL, size, Lua syntax and SHA-256. A SHA-256 mismatch prevents staging; a change after staging prevents installation. It never installs automatically. The OpenOS `wget` command is tried first; a bounded OpenComputers `internet.request` stream is a fallback.

**Security note:** SHA-256 verifies that the downloaded bundle matches the manifest; it does not authenticate the publisher if the manifest itself is compromised. There are no signed releases in v0.6.4. Only use the trusted project repository. GitHub Raw cache propagation may cause temporary checksum mismatches when both files are changed.

## Build and tests

```sh
python3 tools/build.py
python3 tools/write_update_manifest.py
sh tests/run_all.sh
```

The suite uses `texlua` / Lua 5.3 and mocked OpenComputers APIs. It does not verify in-game networking or actual update completion until tested on Minecraft hardware.

## Repository layout

- `src/nexus/`: modular source code
- `dist/nexus.lua`: current stable single-file build
- `releases/`: preserved earlier release(s)
- `tools/`: deterministic bundler and manifest writer
- `tests/`: regression, GUI, SHA-256 and download safety tests
- `docs/`: technical and Croatian deployment documentation

## Publishing

Never update `update.nxs` without publishing the matching `dist/nexus.lua`. For a new stable version, run `python3 tools/build.py && python3 tools/write_update_manifest.py && sh tests/run_all.sh`. Publish the release file and both manifests in one commit. GitHub Raw caching may briefly return mismatched versions; retry after propagation instead of bypassing SHA-256.
