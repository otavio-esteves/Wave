#!/usr/bin/env bash
set -euo pipefail

for dependency in rg timeout; do
    if ! command -v "$dependency" >/dev/null; then
        printf 'Missing validation tool: %s\n' "$dependency" >&2
        exit 2
    fi
done

project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
godot_bin="${GODOT_BIN:-godot}"
resume_suite="${1:-}"
resume_suite="${resume_suite#--from=}"
if [[ $# == 0 ]]; then resume_suite=""; fi
check_root="$(mktemp -d "${TMPDIR:-/tmp}/wave-check.XXXXXX")"
export XDG_CONFIG_HOME="$check_root/config"
export XDG_CACHE_HOME="$check_root/cache"
export XDG_DATA_HOME="$check_root/import"
PYTHONDONTWRITEBYTECODE=1 python3 "$project_root/tests/pacing_tools_test.py"
PYTHONDONTWRITEBYTECODE=1 python3 "$project_root/tests/intercity_pacing_tools_test.py"
PYTHONDONTWRITEBYTECODE=1 python3 "$project_root/tests/pilot_benchmark_tools_test.py"
PYTHONDONTWRITEBYTECODE=1 python3 "$project_root/tests/pilot_profile_tools_test.py"
"$godot_bin" --headless --path "$project_root" --editor --quit

suites="fixture_input city_generation city_physics pilot_visual_lod city_loading driving terrain ground_navigation curb_access map_ground_access handling high_speed car_visual vehicle_reflection camera_input neighborhood race rally rally_access rally_visual audio menu city_map pilot_city neighborhood_composition pilot_optimization pilot_trip pilot_curb day_night performance corridor corridor_cells streaming hlod intercity town_access stop_maneuver elevation elevation_access lookout_trip"
if [[ -n "$resume_suite" && " $suites " != *" $resume_suite "* ]]; then
    printf 'Unknown resume suite: %s\n' "$resume_suite" >&2
    exit 2
fi
for suite in $suites; do
    if [[ -n "$resume_suite" && "$suite" != "$resume_suite" ]]; then continue; fi
    resume_suite=""
    export XDG_DATA_HOME="$check_root/$suite"
    suite_log="$check_root/$suite.log"
    suite_args=()
    if [[ "$suite" == pilot_city && -n "${WAVE_REGENERATED_PILOT:-}" ]]; then
        # An independently completed isolated build may be supplied by a caller.
        # The suite still compares all saved geometry, placements and collision.
        suite_args=(-- "--regenerated-scene=$WAVE_REGENERATED_PILOT")
    fi
    if ! timeout "${WAVE_SUITE_TIMEOUT:-1200}s" "$godot_bin" --headless --path "$project_root" --fixed-fps 60 --script "res://tests/${suite}_smoke.gd" "${suite_args[@]}" > "$suite_log" 2>&1; then
        cat "$suite_log"
        exit 1
    fi
    cat "$suite_log"
    engine_errors="$(rg 'SCRIPT ERROR:|ERROR:|WARNING:.*ObjectDB.*leaked' "$suite_log" || true)"
    if [[ "$suite" == streaming ]]; then
        # This suite deliberately requests one missing resource.
        engine_errors="$(printf '%s\n' "$engine_errors" | rg -v "ERROR: (Cannot open file 'user://missing-cell.tscn'|Failed loading resource: user://missing-cell.tscn\\.)" || true)"
    fi
    if [[ -n "$engine_errors" ]]; then
        printf 'Unexpected engine diagnostics in source suite: %s\n' "$suite" >&2
        exit 1
    fi
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
