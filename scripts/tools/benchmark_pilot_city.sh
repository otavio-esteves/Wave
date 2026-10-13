#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
godot_bin="${GODOT_BIN:-godot}"
output="${1:?Usage: benchmark_pilot_city.sh NEW_OUTPUT BASELINE_PCK CANDIDATE_PCK --exclusive-use|--diagnostic}"
baseline="$(realpath -- "${2:?Baseline PCK required}")"
candidate="$(realpath -- "${3:?Candidate PCK required}")"
scope="${4:?Declare --exclusive-use or --diagnostic}"
case "$scope" in
    --exclusive-use) passes=3 ;;
    --diagnostic) passes=1 ;;
    *) printf 'Unknown scope: %s\n' "$scope" >&2; exit 2 ;;
esac
mkdir "$output"
output="$(realpath -- "$output")"
cp "$project_root/tests/fixture_input.gd" "$output/fixture_input.gd"
cp "$project_root/tests/pilot_city_smoke.gd" "$output/pilot_city_smoke.gd"
cp "$project_root/tests/pilot_benchmark.gd" "$output/pilot_benchmark.gd"
git -C "$project_root" diff HEAD > "$output/source.patch"
python3 - "$output" "$baseline" "$candidate" "$scope" <<'PY'
import hashlib, json, os, platform, sys
from pathlib import Path
output = Path(sys.argv[1])
context = {'platform': platform.platform(), 'scope': sys.argv[4],
           'exclusive_use_declared': sys.argv[4] == '--exclusive-use',
           'memory_target_certified': False, 'memory_scope': '16 GB installed; RSS monitored, not 8 GB certification',
           'versions': {label: {'path': path, 'sha256': hashlib.sha256(Path(path).read_bytes()).hexdigest()}
                        for label, path in zip(['before', 'after'], sys.argv[2:4])},
           'fixture_sha256': {path.name: hashlib.sha256(path.read_bytes()).hexdigest()
                              for path in output.glob('*.gd')}}
for name, path in [('memory', '/proc/meminfo'), ('machine', '/sys/class/dmi/id/product_name')]:
    context[name] = Path(path).read_text() if Path(path).exists() else None
(output / 'context.json').write_text(json.dumps(context, indent=2) + '\n')
PY

run_pass() {
    local version="$1" gpu="$2" pass="$3" package="$4"
    shift 4
    local folder="$output/$version-$gpu-$pass"
    mkdir "$folder"
    export XDG_DATA_HOME="$folder/data"
    export XDG_CONFIG_HOME="$folder/config"
    export XDG_CACHE_HOME="$folder/cache"
    local profile=--economy
    # PCI selection avoids Mesa's default-device ordering and the invalid "0" selector.
    export DRI_PRIME
    DRI_PRIME="$(python3 - "$gpu" <<'PY'
import sys
from pathlib import Path
vendor = '0x8086' if sys.argv[1] == 'intel' else '0x1002'
devices = sorted({card.resolve() for card in Path('/sys/class/drm').glob('card[0-9]*/device')
                  if (card / 'vendor').exists() and (card / 'vendor').read_text().strip() == vendor})
if not devices:
    raise SystemExit('Requested GPU not found: ' + sys.argv[1])
print('pci-' + devices[0].name.replace(':', '_').replace('.', '_'))
PY
)"
    if [[ "$gpu" == radeon ]]; then profile=--medium; fi
    printf 'Pilot benchmark: %s / %s / %s\n' "$version" "$gpu" "$pass"
    local result=0
    python3 "$project_root/scripts/tools/hardware_monitor.py" --output "$folder/hardware.jsonl" -- \
        "$godot_bin" --path "$output" --main-pack "$package" --rendering-method gl_compatibility \
        --script "$output/pilot_benchmark.gd" -- "$profile" "--expected-gpu=$gpu" "$@" > "$folder/run.log" 2>&1 || result=$?
    printf '%s\n' "$result" > "$folder/exit-code.txt"
    if ((result != 0)); then printf 'Pass failed with exit %s; preserving evidence and continuing comparisons.\n' "$result"; fi
    tail -n 2 "$folder/run.log"
}

# Before/after alternate on the same GPU to reduce ordering and thermal bias.
for gpu in intel radeon; do
    for ((pass=1; pass<=passes; pass++)); do
        run_pass before "$gpu" "$pass" "$baseline"
        run_pass after "$gpu" "$pass" "$candidate"
    done
    if [[ "$scope" == --exclusive-use ]]; then
        run_pass after "$gpu" long "$candidate" --long-session
    fi
done
python3 "$project_root/scripts/tools/analyze_pilot_benchmark.py" "$output"
