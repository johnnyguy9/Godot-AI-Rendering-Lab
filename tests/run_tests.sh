#!/usr/bin/env bash
set -euo pipefail

GODOT_BIN="${GODOT_BIN:-${GODOT:-godot}}"

"${GODOT_BIN}" --headless --path . --import
"${GODOT_BIN}" --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit
