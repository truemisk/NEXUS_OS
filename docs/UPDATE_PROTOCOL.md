# NEXUS GitHub stable update protocol — v0.6.4

## Format

`update.nxs` is a bounded (<=2048 B) UTF-8/ASCII key-value document parsed by OpenOS Lua 5.3:

```text
# NEXUS-UPDATE-MANIFEST: 1
channel=stable
version=0.6.4
url=https://raw.githubusercontent.com/truemisk/NEXUS_OS/main/dist/nexus.lua
sha256=<64 lowercase hexadecimal characters>
size=<decimal byte count>
```

Allowed keys: `channel`, `version`, `url`, `sha256`, `size` (each once). Values must pass validation. The channel must be `stable` and the URL must match the compiled-in official GitHub Raw URL exactly. No redirect URL is accepted from the manifest as a new fetch target. The JSON mirror is for tooling; NEXUS reads only `update.nxs`.

## Workflow

1. The user selects **Check GitHub updates**; NEXUS downloads and parses the manifest.
2. The user selects **Download GitHub release**. NEXUS refetches the manifest to prevent using stale metadata, downloads the bundle to `download.part`, checks size, SHA-256, Lua header/version and syntax, then stages the release.
3. The UI shows the staged release. The user explicitly selects Install and confirms it.
4. Immediately before install, NEXUS verifies the staged GitHub hash again. The existing installer backs up the active OS into `previous.lua`, writes a trial transaction marker and promotes the staged release.
5. Successful launch confirms the trial. An interrupted trial attempts rollback at the next start.

No automatic installs. The legacy Pastebin input is still available for manual trusted IDs and is not SHA-256 verified unless staged with trusted external metadata.

## Threat model and caveats

SHA-256 protects against accidental or malicious changes to a downloaded file that are not reflected in the fetched manifest. The manifest is **not digitally signed** and can itself be replaced by someone with write access to the repository. TLS plus pinned host reduce but do not eliminate that trust exposure. Shell `wget` is used first because it has been demonstrated on the user's Minecraft machine. An OpenComputers HTTP iterator fallback has a bounded download limit. The `wget` fallback cannot enforce a streaming size cap and depends on the pinned GitHub endpoint.

GitHub Raw caching may temporarily mix releases if manifest and bundle are updated concurrently. This is a safe failure because mismatching SHA-256 blocks installation; retry later. Future improvements could pin immutable Git commits or releases in the manifest and use signed manifests.
