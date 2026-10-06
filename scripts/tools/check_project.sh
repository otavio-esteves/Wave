#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
godot_bin="${GODOT_BIN:-godot}"
check_root="$(mktemp -d "${TMPDIR:-/tmp}/wave-check.XXXXXX")"
export XDG_CONFIG_HOME="$check_root/config"
export XDG_CACHE_HOME="$check_root/cache"
export XDG_DATA_HOME="$check_root/import"
"$godot_bin" --headless --path "$project_root" --editor --quit

for suite in driving terrain handling high_speed neighborhood race rally rally_visual audio menu performance corridor corridor_cells streaming hlod; do
    export XDG_DATA_HOME="$check_root/$suite"
    "$godot_bin" --headless --path "$project_root" --fixed-fps 60 --script "res://tests/${suite}_smoke.gd"
    if [[ "$suite" == audio || "$suite" == menu ]]; then
        "$godot_bin" --headless --path "$project_root" --script "res://tests/${suite}_smoke.gd" -- --verify-persistence
    fi
done
# Regenerate only into isolated user data; never overwrite production maps.
export XDG_DATA_HOME="$check_root/offline"
for entry in neighborhood:neighborhood race_track:race rally_stage:rally; do
    tool="${entry%%:*}"
    artifact="${entry##*:}"
    "$godot_bin" --headless --path "$project_root" --script "res://scripts/tools/build_${tool}.gd" -- "--output=user://${artifact}-generated.tscn"
done
"$godot_bin" --headless --path "$project_root" --script res://tests/offline_assembly_smoke.gd
printf 'All Wave checks passed. Test data: %s\n' "$check_root"
