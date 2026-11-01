# File safety and command execution

- The File Manager is a convenience interface to live OpenOS files. No writes
  are performed merely by opening, browsing or previewing a file.
- Mutations block collisions; the program refuses overwriting. Protected path
  checks cover selected sensitive locations; recursive deletion is disabled.
  Deleting an item requires pressing `Y` in a confirmation dialog.
- These are NOT security boundaries, and do not guarantee protection against
  symlink/alias tricks, special mounts or other OpenOS behaviors. Back up data
  before modifying files on production disks.
- The Terminal `run COMMAND` hands control to the real OpenOS shell and has
  the same permissions and risks as typing that command at the OpenOS prompt.
  Only run commands you trust. No automated privileged tasks are scheduled.
- NEXUS does not rewrite EEPROM, boot scripts or any installed OpenOS program.
