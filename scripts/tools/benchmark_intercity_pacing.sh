#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
godot_bin="${GODOT_BIN:-godot}"
output="${1:?Usage: benchmark_intercity_pacing.sh NEW_OUTPUT_DIR [--balanced]}"
if [[ -e "$output" ]]; then
    printf 'Output already exists: %s\n' "$output" >&2
    exit 1
fi
mkdir -p "$output"
output="$(cd -- "$output" && pwd)"
extra=()
if [[ "${2:-}" == --balanced ]]; then extra+=(--balanced); fi
git -C "$project_root" rev-parse HEAD > "$output/base-commit.txt"
git -C "$project_root" status --short > "$output/worktree-status.txt"
git -C "$project_root" diff --binary > "$output/tracked-changes.patch"
python3 - "$project_root" "$output" <<'PY'
import hashlib, json, pathlib, sys
root, output = map(pathlib.Path, sys.argv[1:])
paths = [root / 'project.godot']
for folder in ['scripts', 'tests', 'scenes', 'assets']:
    paths.extend(path for path in (root / folder).rglob('*')
                 if path.is_file() and path.suffix != '.import')
(output / 'source-hashes.json').write_text(json.dumps(
    {str(path.relative_to(root)): hashlib.sha256(path.read_bytes()).hexdigest()
     for path in sorted(paths)}, indent=2) + '\n')
PY
# Alternate order between pairs; one visible game at a time, isolated preferences/cache.
for arm in 1-on 1-off 2-off 2-on 3-on 3-off; do
    run="$output/$arm"
    mkdir -p "$run"
    capture_args=()
    if [[ "$arm" == *-off ]]; then capture_args+=(--no-capture); fi
    printf 'Starting %s\n' "$arm"
    XDG_DATA_HOME="$run/data" XDG_CONFIG_HOME="$run/config" XDG_CACHE_HOME="$run/cache" \
        timeout 240 python3 "$project_root/scripts/tools/hardware_monitor.py" --output "$run/hardware.jsonl" -- \
        "$godot_bin" --path "$project_root" --rendering-method gl_compatibility \
        --script res://tests/intercity_smoke.gd -- --foreground --no-vsync \
        --pacing-diagnostic "${extra[@]}" "${capture_args[@]}" > "$run/run.log" 2>&1
    printf 'Completed %s\n' "$arm"
done
