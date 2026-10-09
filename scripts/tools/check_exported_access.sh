#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
godot_bin="${GODOT_BIN:-godot}"
package="${1:-$project_root/builds/linux/Wave.pck}"
package="$(realpath -- "$package")"
check_root="$(mktemp -d "${TMPDIR:-/tmp}/wave-pack-access.XXXXXX")"
export XDG_CONFIG_HOME="$check_root/config"
export XDG_CACHE_HOME="$check_root/cache"
export XDG_DATA_HOME="$check_root/data"

cp "$project_root/tests/pilot_city_smoke.gd" "$check_root/pilot_city_smoke.gd"
cp "$project_root/tests/pilot_curb_smoke.gd" "$check_root/pilot_curb_smoke.gd"

# External fixtures load gameplay resources exclusively from the export.
cp "$project_root/tests/rally_access_smoke.gd" "$check_root/rally_access_smoke.gd"
cp "$project_root/tests/town_access_smoke.gd" "$check_root/town_access_smoke.gd"
sed 's|extends "res://tests/town_access_smoke.gd"|extends "town_access_smoke.gd"|' \
    "$project_root/tests/stop_maneuver_smoke.gd" > "$check_root/stop_maneuver_smoke.gd"
sed 's|extends "res://tests/rally_access_smoke.gd"|extends "rally_access_smoke.gd"|' \
    "$project_root/tests/map_ground_access_smoke.gd" > "$check_root/map_ground_access_smoke.gd"
cat > "$check_root/package_guard.gd" <<'GD'
extends SceneTree

func _initialize() -> void:
	if not FileAccess.file_exists("res://project.binary") or FileAccess.file_exists("res://project.godot"):
		push_error("Access validation requires the exported resource package")
		quit(1)
		return
	print("PASS: access validation uses the exported resource package")
	quit(0)
GD

"$godot_bin" --headless --path "$check_root" --main-pack "$package" \
    --script "$check_root/package_guard.gd" > "$check_root/package-guard.log" 2>&1
cat "$check_root/package-guard.log"
for suite in rally_access map_ground_access town_access stop_maneuver pilot_city pilot_curb; do
    suite_args=()
    if [[ "$suite" == pilot_city ]]; then suite_args=(-- --exported); fi
    if ! "$godot_bin" --headless --path "$check_root" --main-pack "$package" \
        --fixed-fps 60 --script "$check_root/${suite}_smoke.gd" "${suite_args[@]}" > "$check_root/$suite.log" 2>&1; then
        cat "$check_root/$suite.log"
        exit 1
    fi
    cat "$check_root/$suite.log"
done
printf 'All exported access checks passed. Test data: %s\n' "$check_root"
