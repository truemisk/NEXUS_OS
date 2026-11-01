#!/usr/bin/env python3
"""Deterministically bundle modular NEXUS Lua into one OpenOS-ready text file."""
from pathlib import Path
import hashlib
import os
import re

version = os.environ.get("NEXUS_RELEASE_VERSION", "0.6.2")
if not re.fullmatch(r"\d+\.\d+\.\d+", version):
    raise ValueError("Invalid semantic version")

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "src" / "nexus"
DIST = ROOT / "dist"
DIST.mkdir(exist_ok=True)
modules = sorted(SRC.rglob("*.lua"))
chunks = [
    f"-- NEXUS OS Core v{version} | Phase 5B Repair | OpenOS (Lua 5.3)",
    "-- NEXUS-DISTRIBUTION: 1",
    f"-- NEXUS-VERSION: {version}",
    "-- Modular source layout: see README.md",
    "-- Single-file distribution: startup remains opt-in; never edits boot files.",
    "",
]
for file in modules:
    name = "nexus." + ".".join(file.relative_to(SRC).with_suffix("").parts)
    body = file.read_text(encoding="utf-8").rstrip()
    body = re.sub(r"v0\.6\.[0-9]+", "v" + version, body)
    if file.name == 'update.lua':
        body = re.sub(r"M\.VERSION='\d+\.\d+\.\d+'", "M.VERSION='" + version + "'", body)
    chunks.append(f'package.preload["{name}"] = function(...)')
    chunks.append(body)
    chunks.append("end")
    chunks.append("")
chunks += [
    'local Update = require("nexus.core.update")',
    'local updater = Update.new()',
    '-- Interrupted replacement after power loss: restore previous release.',
    'if not _G.__nexus_trial and updater.fs.exists(Update.TXN) then',
    '  local repaired, why = updater:recoverInterrupted()',
    '  if not repaired then io.stderr:write("NEXUS recovery: "..tostring(why).."\\n"); return false, why end',
    '  if updater.fs.exists(Update.CORE) then return dofile(Update.CORE) end',
    'end',
    'local run = require("nexus.main")',
    'local ok, result = run()',
    'if not ok then io.stderr:write("NEXUS failed: "..tostring(result).."\\n"); return false, result end',
    'local action = type(result)=="table" and result.updateAction',
    'if action=="install" or action=="rollback" then',
    '  local changed, why',
    '  if action=="install" then changed,why=updater:commit() else changed,why=updater:rollback() end',
    '  if not changed then io.stderr:write("NEXUS update: "..tostring(why).."\\n");return false,why end',
    '  for name in pairs(package.loaded) do if name:match("^nexus%.") then package.loaded[name]=nil end end',
    '  _G.__nexus_trial=true',
    '  local launched, success, detail=pcall(dofile,Update.CORE)',
    '  _G.__nexus_trial=nil',
    '  if launched and success==true then',
    '    if action=="install" then updater:finish() end',
    '    return true,detail',
    '  end',
    '  if action=="install" then',
    '    local restored,whyRollback=updater:rollback()',
    '    io.stderr:write("NEXUS update failed; rollback: "..tostring(whyRollback or restored).."\\n")',
    '  end',
    '  return false,tostring(detail or success)',
    'end',
    'return true, result',
    '',
]

output = "\n".join(chunks)
filename = "nexus.lua" if version=="0.6.2" else f"nexus-test-update-v{version}.lua"
(DIST / filename).write_text(output, encoding="utf-8")
manifest = hashlib.sha256(output.encode()).hexdigest() + "  "+filename+"\n"
if version=="0.6.2":
    (DIST / "SHA256SUMS").write_text(manifest, encoding="ascii")
print("Build:", DIST / filename, len(output.encode()), "bytes")
print("Modules:", len(modules))
print("SHA256:", manifest.split()[0])
