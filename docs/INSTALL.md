# Install Phase 3 on OpenOS

Keep the working v0.2.0 as a recovery option. Do not edit EEPROM or `/boot`.

1. Publish the plain text of `dist/nexus.lua` to a public Pastebin paste.
2. Type at the OpenOS command prompt:

   ```
   pastebin get NEW_ID /home/nexus30.lua
   /home/nexus30.lua
   ```

3. On the desktop, press 1 for File Manager, 2 for Terminal and 3 for Monitor.
4. Esc from an app returns to Home. Esc from Home exits and restores OpenOS.
5. If Pastebin isn't available, use a compatible OpenOS filesystem-transfer
   technique; don't assume the Linux filesystem is mounted in Minecraft.

Existing settings at `/home/nexus/settings-v2.cfg` are reused. Other user files
are only changed when explicitly manipulated in File Manager or OpenOS Terminal.
See the complete Croatian walkthrough in `README_HR.md`.
