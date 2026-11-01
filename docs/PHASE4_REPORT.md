# Phase 4 completion report — source/test checkpoint

Date: 2026-11-01. Target: OpenOS 1.8.x, Lua 5.3, existing OpenComputers screen and GPU; verified environment in the previous session used multiple GPU cards, with terminal GPU bound to screen.

## Scope

New modules: `core/logger.lua`, `core/services.lua`, `core/recovery.lua`, `core/session.lua`, `core/diagnostics.lua`, `core/performance.lua`, `apps/control.lua`.

Updated: main event loop/service lifecycle; validated settings-v4 with v2 migration; user-facing input/taskbar; exit confirmation; About and existing app navigation; build packaging. Optional `tools/nexus_startup.lua` added separately.

## Service lifecycle

Each cooperative service is registered at startup, has a minimum refresh interval, protected `tick`, and optional protected `stop`. A service producing 3 errors is disabled and reported without terminating other services. Core and notices are essential and cannot be disabled in System Center. Memory sampling may be stopped. Service cycles run **only while main NEXUS event loop is active**.

## Recovery

NEXUS creates `/home/nexus/session.lock` when it begins and removes it on normal exit. On a subsequent start with existing marker the user is warned; optional services start paused. Component/app/service failures generate log entries, and app manager returns to desktop after protected failures. Fatal errors trigger attempts to restore saved GPU resolution/depth/colors/cursor; a fatal error retains the marker for diagnosis.

## Persistent storage

`/home/nexus/settings-v4.cfg` and `.bak` plus `/home/nexus/logs/system.log` and `.old`. Settings are a whitelisted text format; no Lua evaluation. Older settings-v2 are only read as migration input. User's files are not automatically deleted/renamed by installing the new GUI. File Manager continues to permit selected user-requested file mutations.

## Optional startup

`tools/nexus_startup.lua` is an opt-in editor of `/home/.shrc` (not BIOS, `/boot`, `rc` nor EEPROM). Explicit `enable YES` required. The generated bootstrap uses `/home/nexus/startup.guard` to avoid repeated failed autostarts; `disable` preserves unrelated shell lines. Separate bootstrap is only relevant if the user elects to activate it.

## Testing

- 42/42 Phase 3 functionality regressions, adapted for new exit confirmation and taskbar placement.
- 29/29 Phase 4 modular and UI tests.
- 8/8 isolated autostart tests, including guard/disable.
- 1/1 single-file bundle execution smoke test.
- Total: 80/80 local tests passed.

Tests use simulated GPU, filesystem/clock, event queue, mocked OpenOS APIs and isolated autostart filesystem. **No actual Minecraft/real hardware tests were run for Phase 4**. Actual memory headroom, GPU behavior, .shrc execution and save/restore on the user's modpack are pending.

## Risks/limits

- OpenOS shell handoff can block; full isolation and multitasking are out of scope.
- Unexpected shutdown leaves `session.lock` and triggers recovery warning, also for power loss (not proof of a software crash).
- .shrc triggers each interactive shell load rather than necessarily exactly once per physical boot.
- Logger writes and .shrc installer are unprivileged from a Lua/API perspective but depend on writable filesystem, and are not security boundaries.
- Under very small GPU resolutions fewer taskbar actions are visible; HOME, BACK, EXIT prioritized.
- System Center service statuses are measurements of in-process services, not claims about system-wide OpenOS daemons.
