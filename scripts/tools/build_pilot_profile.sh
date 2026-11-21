#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
godot_bin="${GODOT_BIN:-godot}"
output="${1:?Usage: build_pilot_profile.sh OUTPUT_DIRECTORY [--route]}"
mode="${2:-}"
if [[ -n "$mode" && "$mode" != --route ]]; then
    printf 'Unknown pilot diagnostic mode: %s\n' "$mode" >&2
    exit 2
fi
mkdir -p "$output"
output="$(cd -- "$output" && pwd)"
staging="$(mktemp -d "${TMPDIR:-/tmp}/wave-profile-project.XXXXXX")"
printf '%s\n' "$staging" > "$output/staging-path.txt"
# Resource paths stay the same; the source project configuration is untouched.
for folder in assets scripts scenes addons; do
    ln -s "$project_root/$folder" "$staging/$folder"
done
mkdir -p "$staging/.godot"
ln -s "$project_root/.godot/imported" "$staging/.godot/imported"
cp "$project_root/.godot/global_script_class_cache.cfg" "$project_root/.godot/uid_cache.bin" "$staging/.godot/"
# Reuse the completed import scan as well as the imported assets. The editor
# still checks changed files; a diagnostic export need not rescan old generations.
if [[ -f "$project_root/.godot/editor/filesystem_cache10" ]]; then
    mkdir -p "$staging/.godot/editor"
    cp "$project_root/.godot/editor/filesystem_cache10" "$staging/.godot/editor/"
fi
cp "$project_root/export_presets.cfg" "$staging/"
python3 - "$project_root" "$staging" "$mode" <<'PY'
import shutil
import re
import sys
from pathlib import Path
project = Path(sys.argv[1])
root = Path(sys.argv[2])
source = (project / 'project.godot').read_text()
if sys.argv[3] == '--route':
    entry = 'run/main_scene="res://pilot_benchmark/start.tscn"\nrun/main_loop_type="PilotBenchmarkLoop"'
    fixtures = root / 'pilot_benchmark'
    fixtures.mkdir()
    for name in ('fixture_input.gd', 'pilot_city_smoke.gd', 'pilot_benchmark.gd'):
        shutil.copyfile(project / 'tests' / name, fixtures / name)
    (fixtures / 'loop.gd').write_text('class_name PilotBenchmarkLoop\nextends "pilot_benchmark.gd"\n')
    (fixtures / 'start.tscn').write_text('[gd_scene format=3]\n[node name="PilotBenchmarkStart" type="Node"]\n')
else:
    entry = 'run/main_scene="res://pilot_profile.tscn"'
    (root / 'pilot_profile.tscn').write_text('''[gd_scene load_steps=2 format=3]
[ext_resource type="Script" path="res://scripts/tools/pilot_profile.gd" id="1"]
[node name="PilotProfile" type="Node"]
script = ExtResource("1")
''')
source, replacements = re.subn(r'^run/main_scene=.*$', lambda _: entry, source, flags=re.MULTILINE)
if replacements != 1:
    raise SystemExit('Expected a single main scene in the project settings')
(root / 'project.godot').write_text(source)
PY
if [[ -d "$project_root/tools/godot/export_templates" ]]; then
    export XDG_DATA_HOME="$project_root/tools"
fi
timeout "${WAVE_IMPORT_TIMEOUT:-600}s" "$godot_bin" --headless --editor --path "$staging" --import > "$output/import.log" 2>&1
if rg -n 'SCRIPT ERROR:|ERROR:' "$output/import.log"; then
    exit 1
fi
executable=WaveProfile.x86_64
if [[ "$mode" == --route ]]; then executable=WavePilotRoute.x86_64; fi
timeout "${WAVE_EXPORT_TIMEOUT:-900}s" "$godot_bin" --headless --path "$staging" --export-release Linux "$output/$executable" > "$output/export.log" 2>&1
if rg -n 'SCRIPT ERROR:|ERROR:' "$output/import.log" "$output/export.log"; then
    exit 1
fi
printf 'Native diagnostic build: %s/%s\n' "$output" "$executable"
