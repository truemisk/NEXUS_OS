#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
texlua tests/test_phase3_regression.lua
texlua tests/test_phase4.lua
texlua tests/test_phase5a.lua
texlua tests/test_phase5a_gui.lua
texlua tests/test_autostart.lua
texlua tests/test_phase5a_callable_full.lua
texlua tests/test_bundle.lua
texlua tests/test_phase5b.lua
texlua tests/test_phase5b_gui.lua
texlua tests/test_release5b.lua
texlua tests/test_repair.lua
texlua tests/syntax_check.lua
texlua tests/test_github_updates.lua
texlua tests/test_github_gui.lua
texlua tests/test_release065.lua
