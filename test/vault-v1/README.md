# NEXUS Vault V1 hardware candidate

Read-only Vault Storage development candidate from source commit `d03a202`
(`feature/vault-storage`). Simulator validated; physical Minecraft validation
is pending. The official NEXUS version remains 0.6.5. This is not a stable release.
The bundle is copied byte-for-byte from `artifacts/vault-build/nexus.lua`.

Vault discovers all connected Transposers and adjacent inventories, reads item
names/counts/slots, and provides Storage, Items, Search, Overview and Config views.
Source identities combine the actual Transposer address and side. No physical
inventory transfers or redstone changes are implemented by Vault.

## Download and manual launch in OpenOS

Exit the running NEXUS normally. Download to this separate file:

```sh
wget https://raw.githubusercontent.com/truemisk/NEXUS_OS/hardware-test/test/vault-v1/nexus.lua /home/nexus-vault-v1.lua
lua /home/nexus-vault-v1.lua
```

If that candidate filename already exists, preserve or rename the old candidate
before downloading. Do not overwrite `/home/osv4.lua` or change autostart.
Existing Phase 6 test files remain at `test/phase6/`.

The candidate uses the normal NEXUS settings/log directory; use a test computer
or back up `/home/nexus` if those preferences must remain untouched. Vault aliases
and exclusions use `/home/nexus/vault-v1.cfg`. Resolve any pending update
transaction in the known-good installation before testing. Do not use Update
Center to install or roll back updates from this candidate.

## Integrity

Bundle size: 239455 bytes. SHA-256:

```text
dc99b3aeb8e8032ec6d98d2a02911cbb432b8f2da29ccab332e63073a96e6a8f
```

On Linux, download `nexus.lua` and `SHA256SUMS` from this directory together and
run `sha256sum -c SHA256SUMS`. On OpenOS use a trusted SHA-256 utility if installed;
OpenOS does not necessarily include one. Do not treat a file-size check as a
cryptographic checksum check.

## First physical test

1. Open VAULT from the launcher. Wait for the scan to finish and confirm that the
   connected Transposer is discovered dynamically.
2. Open Storage and verify the full address, side/direction and chest capacity.
3. Compare several actual Minecraft item names, quantities and one-based slot
   numbers with the chest. Inspect details for long labels and registry IDs.
4. Rename a source, search it and its items, sort quantities, and open an item
   location. If two access paths view the same chest, manually exclude the known
   duplicate from totals. Physical duplicate detection is not automatic.
5. Change chest contents manually in Minecraft and Refresh. Old data must be
   marked stale during refresh; restricted metadata must remain unavailable.
6. Disconnect/reconnect the Transposer and refresh after each change. Verify
   stale/unavailable states, alias retention and scan recovery.
7. Test 160x50 and 80x25, keyboard/touch navigation, and Cancel during a scan.
8. Exit with NEXUS's on-screen EXIT and confirmation, returning to OpenOS.
   Launch the existing installation manually with `lua /home/osv4.lua` if desired.

Record OC/mod versions, inspection settings, errors, capacity/count comparisons,
RAM and responsiveness. No items should move. Validate the first real chest
before considering any later mutation features.
