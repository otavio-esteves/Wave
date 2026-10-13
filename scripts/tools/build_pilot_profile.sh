#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
godot_bin="${GODOT_BIN:-godot}"
output="${1:?Usage: build_pilot_profile.sh OUTPUT_DIRECTORY}"
mkdir -p "$output"
output="$(cd -- "$output" && pwd)"
staging="$(mktemp -d /tmp/wave-profile-project.XXXXXX)"
printf '%s\n' "$staging" > "$output/staging-path.txt"
# Resource paths stay the same; the source project configuration is untouched.
for folder in assets scripts scenes addons; do
    ln -s "$project_root/$folder" "$staging/$folder"
done
mkdir -p "$staging/.godot"
ln -s "$project_root/.godot/imported" "$staging/.godot/imported"
cp "$project_root/.godot/global_script_class_cache.cfg" "$project_root/.godot/uid_cache.bin" "$staging/.godot/"
cp "$project_root/export_presets.cfg" "$staging/"
python3 - "$project_root/project.godot" "$staging" <<'PY'
import sys
from pathlib import Path
root = Path(sys.argv[2])
source = Path(sys.argv[1]).read_text()
source = source.replace('run/main_scene="res://scenes/ui/main_menu.tscn"', 'run/main_scene="res://pilot_profile.tscn"')
(root / 'project.godot').write_text(source)
(root / 'pilot_profile.tscn').write_text('''[gd_scene load_steps=2 format=3]
[ext_resource type="Script" path="res://scripts/tools/pilot_profile.gd" id="1"]
[node name="PilotProfile" type="Node"]
script = ExtResource("1")
''')
PY
if [[ -d "$project_root/tools/godot/export_templates" ]]; then
    export XDG_DATA_HOME="$project_root/tools"
fi
timeout 180s "$godot_bin" --headless --editor --path "$staging" --import > "$output/import.log" 2>&1
if rg -n 'SCRIPT ERROR:|ERROR:' "$output/import.log"; then
    exit 1
fi
timeout 300s "$godot_bin" --headless --path "$staging" --export-release Linux "$output/WaveProfile.x86_64" > "$output/export.log" 2>&1
if rg -n 'SCRIPT ERROR:|ERROR:' "$output/import.log" "$output/export.log"; then
    exit 1
fi
printf 'Native diagnostic build: %s/WaveProfile.x86_64\n' "$output"
