#!/usr/bin/env bash
# Explicitly select GODOT to use the intended engine; do not install or replace it.
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p work/validation work/godot-data work/godot-cache work/godot-config
export XDG_DATA_HOME="$PWD/work/godot-data"
export XDG_CACHE_HOME="$PWD/work/godot-cache"
export XDG_CONFIG_HOME="$PWD/work/godot-config"
engine="${GODOT:-godot}"
"$engine" --version
run() {
  local name="$1"
  shift
  "$engine" --headless --path . "$@" >"work/validation/$name.log" 2>&1
  if rg -n 'SCRIPT ERROR:|^ERROR:|^FAIL' "work/validation/$name.log"; then
    echo "FAIL: $name (see work/validation/$name.log)"
    exit 1
  fi
  echo "PASS: $name"
}
if [[ "${1:-}" == "--import" ]]; then
  run import --editor --import --quit
fi
run startup --quit-after 4
for suite in tests/*_test.gd; do
  run "$(basename "$suite" .gd)" --script "res://$suite"
done
