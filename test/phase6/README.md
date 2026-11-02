# NEXUS Phase 6 hardware test

Development candidate `phase6-574d975-8f2aeb0e11ee`; simulator validated, physical hardware validation pending. This is a test build, not a stable release.

Preserve the existing `/home/osv4.lua`, autostart and NEXUS configuration; use a test computer or back up `/home/nexus` because settings and logs are shared. Resolve any pending update transaction in the known-good installation before testing. Do not install or roll back updates from this candidate.

On Linux verify the download with `sha256sum -c SHA256SUMS` in this directory. Expected SHA-256: `612176fa46b72b826d52e259058b81de6d5e2fee6e2d8118f9f95c2067cf3be9`. On OpenOS use an available trusted SHA-256 tool if installed; OpenOS installations may not provide one by default.

Download to `/home/nexus-phase6/nexus.lua`, then launch manually:

```sh
lua /home/nexus-phase6/nexus.lua
```

Exit using the on-screen EXIT control and launch the existing installation with `lua /home/osv4.lua`.
