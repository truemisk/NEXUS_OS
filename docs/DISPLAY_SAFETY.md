# Display configuration safety

1. Do not adjust the GPU binding, firmware or `/boot`.
2. Settings > Resolution Target shows OpenOS Original and only supported additional presets.
3. Selecting PREVIEW DISPLAY calls `gpu.setResolution` only after a user presses ENTER/taps that row.
4. Confirmation dialog shows `ENTER` to keep the change during this NEXUS session, `ESC` to revert and a 12-second timeout.
5. If the display becomes unreadable, **do nothing for 12 seconds**; NEXUS tries to revert to the previous size. On any exit, it tries to restore the size OpenOS had when NEXUS started.
6. Resolution and GPU bindings are not persisted. If the Minecraft computer hard-reboots, OpenOS manages its own display; NEXUS never installs a startup hook.
7. If the GPU or screen is physically removed, automated rollback cannot be guaranteed. This is a hard hardware limitation.

Manual hardware verification required: original size → Compact preview → ESC revert → Compact preview → ENTER confirm → Exit → original OpenOS size.
