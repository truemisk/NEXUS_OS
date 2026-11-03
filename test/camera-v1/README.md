# Camera Center V1 development candidate

Build `camera-v1-d03a202-08105053e8f4`, official version unchanged at 0.6.5.
Includes the completed Vault and all prior applications. Physical validation is
pending. This directory contains the Camera Center V1 hardware testing candidate.

SHA-256: `b9be49cb3f7f6052be623f8dd521ea9823e18e1439164fd447507bd6bf19ec43`

On Linux verify `sha256sum -c SHA256SUMS` from this directory. In the OpenOS shell, download the separate candidate:

```sh
wget https://raw.githubusercontent.com/truemisk/NEXUS_OS/hardware-test/test/camera-v1/nexus.lua /home/nexus-camera-v1.lua
```
 Do not replace `/home/osv4.lua` or change autostart. Use a test computer or
back up `/home/nexus` if existing preferences/logs must be preserved; normal NEXUS
settings/logs are shared. Camera preferences are isolated in `camera-v1.cfg`.
Resolve pending update transactions in the known-good OS before testing. Do not
use Update Center to install/roll back this candidate.

Exit the current NEXUS and launch manually:

```sh
lua /home/nexus-camera-v1.lua
```

1. Open CAMERA CENTER. Verify the detected full component address with INFO.
2. Leave LOW quality, manual refresh and the default forward read selected.
3. Press SCAN. It samples 91 rays incrementally. Record actual completion time
   and desktop responsiveness; host benchmark timings do not predict OC speed.
4. Compare near/far geometry and the center reading against the scene. A black
   pixel means a valid no-hit ray, dots mean unsampled, and ? means failed reads.
5. Put a block in front of the camera, rescan, remove it and rescan again. Verify
   actual distances change. Put blocks to each side/above/below to check the
   orientation on your mod version and camera facing; do not assume GPS data.
6. Try BALANCED only after LOW is responsive. HIGH uses 861 rays and may take
   substantial time. Shade scale and digital zoom are software settings.
7. Rename the camera and adjust a palette. Exit/reopen Camera Center to verify
   persistence. Periodic settings are saved but scanning resumes paused.
8. If a second camera is available, Rediscover, select it and use Grid. Grid SCAN
   uses 45 rays per visible camera, with at most four simultaneous jobs.
9. Test Cancel mid-scan, disconnect/reconnect, and Rediscover. Verify old snapshots
   are labeled and disconnected devices are not continuously retried.
10. Test 80x25/160x50, themes, INFO, touch, arrows and the visible navigation.
11. Exit with NEXUS's on-screen EXIT and confirmation. Back in OpenOS, run the
    known-good installation manually with `lua /home/osv4.lua` if desired.

No physical rotation, thermal sensing, entity imagery or video is available.
Optional distanceUp/distanceDown choices appear only for reported robot methods.
Keep automatic refresh paused for the first physical tests. Record Computronics/
OC versions, callback errors, center distances, scan duration and free RAM.
No physical hardware test is claimed as passed.
