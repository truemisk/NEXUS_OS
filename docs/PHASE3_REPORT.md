# Phase 3 Engineering Report

Status: LOCAL IMPLEMENTATION COMPLETE; real Minecraft test pending.

Architecture: OpenOS Lua 5.3 program, no kernel replacement; all modules are
bundled through `package.preload` into `dist/nexus.lua` for Pastebin transfer.
The OpenOS terminal GPU selection remains inherited from Phase 1.2 and the
three color themes, config persistence and resolution rollback from Phase 2.

New modules:
- `core/path.lua`: lexical path handling and defensive mutation guardrails
- `core/fileops.lua`: bounded listing, preview, copy/move/rename/mkdir/remove
- `core/console.lua`: in-memory command buffer, history and read-only commands
- `apps/files.lua`: keyboard/touch File Manager view and confirmations
- `apps/terminal.lua`: command-line view
- `apps/monitor.lua`: foreground-only sampling and RAM history

Changed modules: main, apps, input, widgets, desktop, About.
There is one foreground application and **no true multitasking**.

Safety: File Manager prevents collisions/overwrites and nonempty folder deletion;
these are best-effort safeguards, not privilege boundaries. `run COMMAND` is
explicitly a real shell command, with all normal OpenOS privileges. Unsupported
or uncaught OS/modpack behavior remains a live-device validation item.

Tests: `tests/test_phase3.lua` currently 42/42 mock checks pass. The bundled
`dist/nexus.lua` also passes an independent boot/ESC/restore check. Neither
result is evidence of Minecraft real-device validation.

Hardware acceptance in Minecraft:
1. NEXUS GUI boots on user's multi-GPU OC machine.
2. File Manager browses `/home` without unintended mutations.
3. Test-folder create/rename/copy/delete all work; protections refuse overwrite.
4. Terminal built-ins work; `run ls /home` returns to NEXUS after confirmation.
5. Monitor displays real data and changes tabs without crashes.
6. Taskbar/number keys work; F2 does not change NEXUS state.
7. Esc returns to OpenOS with original GPU resolution/colors and working keyboard.

Deferred: VAULT Storage, recursive folder copy, editor, graphical windows,
network services, custom bootloader and Phase 4 background services.
