# Hardware and API assumptions

## User-reported in-game hardware (not tested by this distribution)

- OpenComputers + OpenOS 1.8.8 with Lua 5.3.
- Approx. 384 KiB RAM was reported at OpenOS boot. This is a **target constraint**, not a NEXUS benchmark.
- A working screen (Tier 3 per newest screenshot), attached keyboard; three GPUs detected, two bound to the same screen.
- Writable OpenOS root filesystem.
- Transposer, two chests (54 slots each); Phase 1 does not use them.

## Runtime API calls

- `term.gpu()` and `term.keyboard()` to prefer the working OpenOS terminal hardware.
- `component.list([type])`, `component.proxy(address)` for read-only discovery.
- GPU: `getScreen`, `getResolution`, `maxResolution`, `getDepth`, `getForeground`, `getBackground`, `setForeground`, `setBackground`, `set`, `fill`.
- `computer.freeMemory`, `computer.totalMemory`, `computer.uptime` for live values.
- `event.pull(timeout)`; signals `key_down`, `touch`, `screen_resized` (and alternate `screen_resize`), `interrupted`.
- `keyboard.keys` to avoid inventing keycodes. Fallback key scan codes if an individual name is absent.

## What we avoid

- `gpu.bind`, EEPROM writes, OpenOS startup script edits, network requests, autostart, filesystem writes, inventory actions.
- Forcing maximal resolution. NEXUS adapts to the **current** resolution.
- Assuming the first GPU component is connected to the visible screen.

At screen sizes below 20x8, NEXUS shows a minimal enlargement notice instead of trying to draw a complete desktop.

## Public references checked

- GPU API: https://github.com/MightyPirates/OpenComputers/wiki/Component-GPU
- Signals: https://github.com/MightyPirates/OpenComputers/wiki/Signals
- Component API: https://github.com/MightyPirates/OpenComputers/wiki/API-Component
- OpenOS `term.lua`: https://github.com/MightyPirates/OpenComputers/blob/master-MC1.7.10/src/main/resources/assets/opencomputers/loot/openos/lib/term.lua
- OpenOS `keyboard.lua`: https://github.com/MightyPirates/OpenComputers/blob/master-MC1.7.10/src/main/resources/assets/opencomputers/loot/openos/lib/keyboard.lua

The references document API shapes; they are not evidence that this particular NEXUS build was run in Minecraft.


## v0.1.2: confirmed Minecraft diagnostic (2026-11-01)

Read-only diagnostic shows three GPU components and one screen: terminal GPU `56d3a4e9...` bound to screen `6f1fa8eb...`, second GPU `2d0183c4...` bound to the same screen, and third GPU `230ca5ea...` unbound. Reported free memory: 1557 KiB. NEXUS now chooses the active terminal GPU and does not change bindings. This does not confirm the patched NEXUS has run on the device.

## v0.1.1 launch failure and v0.1.2 fallback

A real OpenOS screenshot shows `No usable GPU/screen pair detected` with an identified terminal GPU and screen. The old validator also required GPU resolution/method checks, so this does **not** prove a missing GPU. v0.1.2 tries the documented proxy API first and `component.invoke` for failed methods; on rejection, reports the failing read and its error. The on-device cause is not yet confirmed.

## Phase 5B redstone
Optional OpenComputers Redstone Card or Redstone I/O component (`redstone`). Supports `getInput(side)`, `getOutput(side)` and explicitly confirmed `setOutput(side, level)` for side 0..5 and level 0/15. Default is read-only; outputs are restored on normal exit when safe. This has not yet been tested on physical in-game Redstone hardware; do not use mission-critical controls.
