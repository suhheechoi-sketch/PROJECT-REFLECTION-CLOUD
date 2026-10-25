#!/usr/bin/env bash
set -euo pipefail
project_dir="$(cd "$(dirname "$0")" && pwd)"
engine="${GODOT:-$project_dir/tools/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64}"
if [[ ! -x "$engine" ]]; then
  echo 'Godot 4.7.2 is required. Set GODOT=/path/to/godot-4.7.2 or open project.godot in that editor.' >&2
  exit 1
fi
version="$("$engine" --version)"
if [[ "$version" != 4.7.2.* ]]; then
  echo "Godot 4.7.2 is required; selected engine reports $version" >&2
  exit 1
fi
exec "$engine" --path "$project_dir" "$@"
