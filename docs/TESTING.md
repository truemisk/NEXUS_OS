# Phase 4 Test Plan

Run in project root with Lua 5.3 `texlua`:

```sh
texlua tests/test_phase3_regression.lua
texlua tests/test_phase4.lua
texlua tests/test_autostart.lua
texlua tests/test_bundle.lua
```

Evidence-backed expected results: 42, 29, 8 and 1 passing respectively. Tests use mocks and cannot replace in-game verification. See README_HR.md for actual Minecraft test checklist.

Test classes: legacy filesystem/terminal/monitor/navigation regression; service states, time-based scheduling, error isolation, logger size cap/rotation/failure, lock-based recovery, configuration migration, diagnostics, memory alerts, System Center actions, desktop app selection, click BACK/EXIT, clean OpenOS GPU restore, opt-in .shrc preservation, guard skip after failed autostart and standalone bundle execution.
