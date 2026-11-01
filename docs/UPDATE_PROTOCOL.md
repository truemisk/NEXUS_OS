# NEXUS Phase 5A update format and rollback protocol

Release text must start with the standard comments:

```lua
-- NEXUS OS Core v0.5.1 | Phase 5A | OpenOS (Lua 5.3)
-- NEXUS-DISTRIBUTION: 1
-- NEXUS-VERSION: 0.5.1
```

The updater accepts whole-release text only, not patch snippets or general Lua scripts. The version must be strictly newer than the currently running version. Download is staged and syntax-checked without executing it. Installation is user-confirmed and performed after UI cleanup.

**Trust model**: Pastebin IDs are user-selected. No signing key, signature verification or secure manifest discovery exists. Neither valid Lua syntax nor a version header proves the code came from the correct author. Only paste an ID from a trusted, independently verified release source.

**Power-loss model**: an old stable file is moved to `previous.lua` and a transaction marker is written before stage promotion. On next launch, NEXUS and its bootstrap can detect the trial marker and attempt rollback. A cut during rename cannot be guaranteed recoverable if OpenOS's filesystem or mount is damaged. The manually retained `osv4-pre5a.lua` is the final fallback.

**Upgrade test**: a separate v0.5.1 smoke build is provided solely to prove that the current v0.5.0 updater accepts a full release, restarts the GUI, and permits rollback. The code is not a Phase 5B release.
