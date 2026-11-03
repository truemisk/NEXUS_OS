# Camera Center V1.1 development candidate

Manual hardware testing build; includes Vault and all prior applications.
Verify with `sha256sum -c SHA256SUMS` in this directory on Linux.
Build ID/source fingerprint/size are recorded in BUILD.json.

Transfer nexus.lua to `/home/nexus-camera-v1.1.lua` using a trusted OpenOS file-transfer method. After publication, download in OpenOS:

```sh
wget https://raw.githubusercontent.com/truemisk/NEXUS_OS/hardware-test/test/camera-v1.1/nexus.lua /home/nexus-camera-v1.1.lua
``` Exit the running NEXUS, then:

```sh
lua /home/nexus-camera-v1.1.lua
```

1. Open CAMERA CENTER and verify both camera addresses.
2. In Settings select FAST (15×9/135 rays) for the first scan. New configurations default to BALANCED (273); existing HIGH preferences remain HIGH.
3. Start manual SCAN. Record duration, sample progress, free RAM and UI responsiveness. Compare enlarged view at all three qualities.
4. Select CYAN DEPTH, GRAYSCALE or FALSE COLOR. These show measured depth; colors are not Minecraft textures or temperatures.
5. Scroll Settings to EDGE ENHANCEMENT and toggle it. Check geometry discontinuities.
6. Complete two scans with matching quality, zoom and direction. Press CHANGE VIEW or V. An unchanged scene should show few/no changes.
7. Place/remove blocks in the cone and rescan. Yellow means distance change, green a new hit, pink a lost hit. Inspect changed count/percentage.
8. Scroll Settings to CHANGE THRESHOLD. Test 0.25/0.5/1/2/4 blocks. Hit/no-hit transitions always count regardless of threshold.
9. Change quality/zoom/direction, then scan: baseline resets. Two compatible scans are required. Grid thumbnails also establish their own compatible baseline.
10. Cancel a scan: it must not replace the previous successful completed pair. Change View shows the completed pair while subsequent scans progress.
11. Select camera two and verify its history is independent. Test grid, INFO, rename, persistence, disconnect/reconnect, and 80×25 if available.
12. Exit cleanly and return to the existing installation with `lua /home/osv4.lua` if that is its installed path.

Keep autostart and existing executable intact. Normal NEXUS settings/logs are shared; back up `/home/nexus` if required. Camera configuration uses `/home/nexus/camera-v1.cfg`, compatible with legacy entries but writes version 2; retain a backup before testing if reverting to the V1 application. Do not use Update Center to install this candidate. Periodic refresh is optional and begins paused.

V1 physical result supplied by user: two cameras work at 160×50; HIGH took about 70 seconds. V1.1 physical results are pending. No transfers, physical rotation, RGB video or entity detection are added.

SHA-256: `806843210ed6208b4184fe394eb1c2287172c87f7074cdf563673228ba83a1be`
Build: `camera-v1.1-87db17e-a1b43c5f2321` (278356 bytes / 45 modules).
