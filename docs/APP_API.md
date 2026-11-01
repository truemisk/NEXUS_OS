# Foreground application API (Phase 3)

A Lua application registers one table:

```lua
return {
  id = 'example', name = 'Example', description = '...',
  open = function(ctx) ... end, -- optional, allocate local state
  draw = function(ctx) ... end, -- required; GPU commands through ctx.gfx
  input = function(action, ctx) return true end, -- optional, true if handled
  tick = function(ctx) return false end, -- optional; true requests redraw
  close = function(ctx) ... end, -- optional, release state
}
```

Applications are NOT independent processes. There is one foreground app.
`ctx.manager:home(ctx)` closes it; `ctx.notify(message,kind)` creates a bounded
notification. Use `ctx.hardware:snapshot()` for true OS metrics. Rendering is
owned by `nexus.ui.widgets`, which fills the correct GPU bounds and draws
consistent header/taskbar. An error in `open/draw/input/tick` is caught and
returns to the desktop with a notification. `close` failures are caught.

OpenOS-specific references must be late-bound for testability. The program
must tolerate missing optional components and keep memory allocations bounded.
Do not start your own infinite `event.pull` loop inside an app. No VAULT
application is included in Phase 3.
