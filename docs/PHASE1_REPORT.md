# NEXUS Core v0.1 — Phase 1 implementation report

Date: 2026-11-01

## Implemented

- Modular Lua 5.3 source plus one-file OpenOS release.
- OpenOS GPU identification without risky rebinding; read-only component discovery.
- Clipped GPU drawing and 1-bit fallback theme.
- Responsive desktop with keyboard and touch navigation and working Exit item.
- Real About and System Information apps.
- Minimal app registry and protected lifecycle for future VAULT integration.
- Event-driven redraws and timed status refresh; no persistent background threads.
- Best-effort terminal cleanup after normal exit or a recoverable error.

## Deliberately excluded

- EEPROM changes; boot hooks; autostart; a replacement kernel.
- Inventory management, network protocol, Transposer actions, external URLs, database or settings persistence.
- Decorative animations, draggable windows, a process scheduler.

## Test results

- `tests/test_core.lua`: 16 local Lua 5.3 test cases passed, 0 failed.
- `texluac -p` parses the generated distribution without reported syntax errors.
- `tests/test_bundle.lua`: standalone generated file launched, rendered, exited and cleared the mock screen successfully.
- In-game test runs: **0** (not available in this workspace).

## Packaging

- `dist/nexus.lua` is the only required in-game source file, roughly 21 KiB.
- `dist/SHA256SUMS` contains the verification digest.
- Regenerate release deterministically using `python3 tools/build.py` on Linux.

## Measured versus estimated

- Actual file size and test counts are measured in this development container.
- Memory of the user's Minecraft system was previously *reported* as approximately 384 KiB, not measured by this build.
- No peak resident memory or FPS claims are made: `computer.freeMemory()` must be checked on real hardware.

## Remaining blockers to complete real-device acceptance

1. Transfer the release file into writable OpenOS storage reliably.
2. Run the on-device checklist in `TESTING.md` on the Tier 2 screen and the chosen working GPU.
3. Evaluate memory usage and screen responsiveness in-game; fix any compatibility or resolution issues observed there.

**Status: Phase 1 implemented and locally validated; final in-game acceptance pending. Do not begin Phase 2.**

## Hotfix v0.1.2 - verification status

The GPU diagnostic from Minecraft detected 3 GPU components, 2 bound to the same screen, and 1557 KiB free memory. The v0.1 launcher previously returned an erroneous "No GPU bound" report. v0.1.2 selects the terminal's GPU/screen first and uses `component.invoke` as a fallback for proxy method failures. It never changes the bindings.

The v0.1.2 code has local simulated tests. It has not yet been run on the actual in-game machine. The exact contents of the user's Pastebin-hosted v0.1 source have not been independently retrieved, so the precise trigger for the earlier error is unknown.

### Validation 2026-11-01 (v0.1.2)

- 25/25 mock-based Lua 5.3 tests passed using LuaTeX `--luaonly` runtime.
- Tests include proxy-only missing functions, proxy getResolution throwing with invocation recovery, end-to-end invocation-backed desktop render, and failure diagnostics.
- Live OpenOS startup is unverified. The precise cause of the v0.1.1 failure remains unknown without a read-only on-device method probe.
