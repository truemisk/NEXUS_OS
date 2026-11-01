#!/usr/bin/env python3
"""Produce matching NEXUS GitHub stable manifests from the built dist/nexus.lua."""
from pathlib import Path
import hashlib
import json
import re

root = Path(__file__).resolve().parent.parent
release = root / 'dist' / 'nexus.lua'
body = release.read_bytes()
head = body[:400].decode('ascii', errors='replace')
version_match = re.search(r'^-- NEXUS-VERSION: (\d+\.\d+\.\d+)\s*$', head, re.M)
if not version_match:
    raise RuntimeError('Bundle lacks NEXUS release header')
version = version_match.group(1)
sha = hashlib.sha256(body).hexdigest()
size = len(body)
url = 'https://raw.githubusercontent.com/truemisk/NEXUS_OS/main/dist/nexus.lua'
manifest = f'# NEXUS-UPDATE-MANIFEST: 1\nchannel=stable\nversion={version}\nurl={url}\nsha256={sha}\nsize={size}\n'
(root / 'update.nxs').write_text(manifest, encoding='ascii')
obj = dict(schema=1, project='NEXUS OS', channel='stable', version=version,
           file='dist/nexus.lua', url=url, sha256=sha, size_bytes=size,
           format='nexus-single-file-lua', requires='OpenOS / OpenComputers / Lua 5.3',
           notes='GitHub Update Center v0.6.4; checked manually and installed with confirmation. SHA256 is not a signature.')
(root / 'update.json').write_text(json.dumps(obj, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')
(root / 'dist' / 'SHA256SUMS').write_text(f'{sha}  nexus.lua\n', encoding='ascii')
print(f'GitHub stable manifest: v{version}, {size} bytes, sha256={sha}')
