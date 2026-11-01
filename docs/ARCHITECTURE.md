# NEXUS v0.4.0 Architecture

`OpenComputers BIOS -> OpenOS -> NEXUS single-foreground GUI -> apps`

Core:
- `main.lua`: startup, state, event dispatch, graphics redraw, orderly teardown.
- `hardware.lua`: select the GPU already serving the OpenOS terminal; do not rebind.
- `apps.lua`: foreground app register/open/draw/input/tick, exceptions handled at app boundary.
- `services.lua`: non-preemptive cooperative service tick loop, with rate caps and isolated failures.
- `logger.lua`: in-RAM ring + persistent rotating log.
- `recovery.lua`: session marker + bounded recent failure reports.
- `config.lua`: whitelist/validated scalar storage separate from earlier settings.
- `session.lua`: in-session navigation counters; no risky state replay.
- `performance.lua`: bounded timed free-RAM samples.
- `diagnostics.lua`: actual API-backed hardware/system checks.
- `display.lua`: 12-second resolution preview with rollback.

Apps: Files, Terminal, Monitor, System Info, Settings, Notifications, System Center, About.

Input: Keyboard numbers/Tab/arrows/Enter; taskbar HOME/BACK/EXIT and app shortcuts. ESC and F1-F12 are not needed; OpenOS's terminal keyboard semantics still apply. OpenOS event.pull drives the single event loop and cooperative services. This is not a kernel, scheduler, or background daemon manager.

Autostart is a separate tool and is disabled until explicit `enable YES`. It modifies only an owned block within `/home/.shrc`, and uses the generated guarded bootstrap to invoke the standalone Lua bundle once a shell starts.
