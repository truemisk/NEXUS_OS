# NEXUS OS

Custom graphical desktop environment for the **Minecraft OpenComputers** mod (Lua 5.3 / OpenOS). NEXUS runs **on top of OpenOS** and does not replace the EEPROM or kernel.

## Latest stable source snapshot

**v0.6.2 — Phase 5B repair** (source snapshot prepared for GitHub import). The tested OpenOS installation path is `/home/osv4.lua`.

[Download the stable single-file Lua release](dist/nexus.lua) · [Croatian documentation](README_HR.md) · [Version history](CHANGELOG.md)

### Features

- Graphical desktop with Cyan, Green CRT and Amber themes
- File Manager, Terminal, System Monitor and System Center
- Safe application navigation without Minecraft-reserved F keys / ESC
- Update Center with manually staged releases and rollback
- Optional autostart, logs, diagnostics and recovery
- Hardware Center (components, redstone, diagnostics and session-only automation)

VAULT Storage is **not** integrated. Hardware writes and updates should be tested on non-critical Minecraft equipment.

## Repository layout

```text
NEXUS_OS/
├── src/nexus/              # Modular Lua source
├── dist/nexus.lua          # Stable OpenOS-ready bundle
├── releases/               # Immutable release snapshots (by convention)
├── tools/                  # Build and utility scripts
├── tests/                  # Simulated regression tests
├── docs/                   # Technical notes
├── update.nxs              # Future Lua-friendly update metadata
└── update.json             # Release metadata for external tooling
```

## Build and test on Linux

```sh
python3 tools/build.py
sh tests/run_all.sh
```

The tests use the `texlua` interpreter and mocked OpenComputers components. They do **not** prove functionality on a live Minecraft computer.

## Update architecture

This repository is the first publishing step toward a **GitHub-backed Update Center**. The current v0.6.2 UI does not yet fetch `update.nxs` or `update.json`. The next updater release will add version discovery, network validation, SHA-256 integrity checking when supported, staged installation and rollback.

**Do not interpret the presence of update metadata as an already-working automatic GitHub update feature.**

For GitHub publication steps, see [GitHub setup (HR)](docs/GITHUB_SETUP_HR.md).
