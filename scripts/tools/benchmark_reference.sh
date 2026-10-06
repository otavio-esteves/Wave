#!/usr/bin/env bash
set -euo pipefail

# Sequential rendered fixtures. The output folder must be new, so settings from
# a previous run cannot silently contaminate a reference measurement.
project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
godot_bin="${GODOT_BIN:-godot}"
benchmark_root="${1:?Usage: benchmark_reference.sh NEW_OUTPUT_FOLDER [urban|residential|vegetation|speed|corridor|streaming|startup|hlod|all] [fixture flags...]}"
route="${2:-all}"
if (( $# > 2 )); then shift 2; else set --; fi
extra_args=("$@")
# Explicit experiment flags are forwarded unchanged and captured by each fixture.
case "$route" in urban|residential|vegetation|speed|corridor|streaming|startup|hlod|all) ;; *) printf 'Unknown route: %s\n' "$route" >&2; exit 2 ;; esac
mkdir "$benchmark_root"
benchmark_root="$(cd -- "$benchmark_root" && pwd)"
git -C "$project_root" rev-parse HEAD > "$benchmark_root/commit.txt"
git -C "$project_root" status --short > "$benchmark_root/worktree-status.txt"
git -C "$project_root" diff > "$benchmark_root/tracked-changes.patch"
# Include untracked code in the source identity as well as tracked scenes.
python3 - "$project_root" "$benchmark_root" "$route" "${extra_args[@]}" <<'PY'
import hashlib, json, os, platform, sys
from pathlib import Path
project, output = map(Path, sys.argv[1:3])
patterns = ['scripts/**/*.gd', 'scripts/tools/*.py', 'scripts/tools/*.sh', 'tests/*.gd', 'scenes/**/*.tscn', 'scenes/**/*.tres', 'scenes/**/manifest.json', 'assets/shaders/**/*.gdshader', 'assets/textures/**/*.png', 'assets/textures/**/*.png.import']
sources = sorted({project / 'project.godot', *(p for pattern in patterns for p in project.glob(pattern))})
metadata = {'route': sys.argv[3], 'fixture_flags': sys.argv[4:], 'platform': platform.platform(), 'gpu_selector_DRI_PRIME': os.getenv('DRI_PRIME'), 'source_sha256': {str(p.relative_to(project)): hashlib.sha256(p.read_bytes()).hexdigest() for p in sources}}
metadata['cache_policy'] = 'fresh isolated roots; startup repeats the same roots for its warm entry' if sys.argv[3] == 'startup' else 'fresh isolated roots for each fixture'
for name, path in [('machine', '/sys/class/dmi/id/product_name'), ('memory', '/proc/meminfo'), ('cpu', '/proc/cpuinfo')]:
    if Path(path).exists():
        metadata[name] = Path(path).read_text()
# Read-only Linux context; missing/driver-specific counters are unavailable.
telemetry_paths = [*Path('/sys/class/power_supply').glob('*/online'), *Path('/sys/class/power_supply').glob('*/status')]
for card in Path('/sys/class/drm').glob('card[0-9]'):
    telemetry_paths.extend(card / 'device' / key for key in ['gpu_busy_percent', 'pp_dpm_sclk', 'pp_dpm_mclk', 'power_dpm_force_performance_level'])
    telemetry_paths.extend((card / 'device/hwmon').glob('hwmon*/temp1_input'))
metadata['hardware_snapshot_before'] = {}
for path in telemetry_paths:
    try:
        metadata['hardware_snapshot_before'][str(path)] = path.read_text().strip()
    except OSError:
        metadata['hardware_snapshot_before'][str(path)] = None
(output / 'run-context.json').write_text(json.dumps(metadata, indent=2))
PY

run_route() {
    local fixture="$1"
    local script="$2"
    shift 2
    local route_root="$benchmark_root/$fixture"
    mkdir -p "$route_root"
    export XDG_CONFIG_HOME="$route_root/config"
    export XDG_CACHE_HOME="$route_root/cache"
    export XDG_DATA_HOME="$route_root/data"
    printf 'Benchmark %s: Compatibility; requested flags %s; output %s\n' "$fixture" "${extra_args[*]}" "$route_root"
    "$godot_bin" --path "$project_root" --rendering-method gl_compatibility --script "res://tests/$script" -- --legacy "$@" "${extra_args[@]}" > "$route_root/run.log" 2>&1
    tail -n 5 "$route_root/run.log"
}

if [[ "$route" == urban || "$route" == all ]]; then run_route urban rendered_route.gd; fi
if [[ "$route" == residential || "$route" == all ]]; then run_route residential rendered_route.gd --residential; fi
if [[ "$route" == vegetation || "$route" == all ]]; then run_route vegetation rally_rendered.gd; fi
if [[ "$route" == speed || "$route" == all ]]; then run_route speed high_speed_smoke.gd; fi
if [[ "$route" == corridor || "$route" == all ]]; then run_route corridor corridor_rendered.gd; fi
if [[ "$route" == streaming || "$route" == all ]]; then run_route streaming streaming_rendered.gd; fi
if [[ "$route" == hlod ]]; then run_route hlod hlod_rendered.gd; fi
if [[ "$route" == startup ]]; then
    # Only this diagnostic reuses caches. Both entries retain their own reports
    # and logs; personal settings/cache and normal reference routes stay isolated.
    run_route startup streaming_rendered.gd --startup-only
    startup_root="$benchmark_root/startup"
    startup_report="$startup_root/data/godot/app_userdata/Wave/streaming.json"
    cp "$startup_report" "$startup_root/cold.json"
    mv "$startup_root/run.log" "$startup_root/cold.log"
    "$godot_bin" --path "$project_root" --rendering-method gl_compatibility --script res://tests/streaming_rendered.gd -- --legacy --startup-only "${extra_args[@]}" > "$startup_root/warm.log" 2>&1
    cp "$startup_report" "$startup_root/warm.json"
    tail -n 5 "$startup_root/warm.log"
fi
printf 'Reference benchmarks finished: %s\n' "$benchmark_root"
