#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
godot_bin="${GODOT_BIN:-godot}"
if [[ -d "$project_root/tools/godot/export_templates" ]]; then
    export XDG_DATA_HOME="$project_root/tools"
fi
mkdir -p "$project_root/builds/linux" "$project_root/builds/windows"
"$godot_bin" --headless --path "$project_root" --export-release Linux "$project_root/builds/linux/Wave.x86_64"
"$godot_bin" --headless --path "$project_root" --export-release Windows "$project_root/builds/windows/Wave.exe"
cat > "$project_root/builds/linux/Wave-quality.sh" <<'LAUNCH'
#!/usr/bin/env bash
set -euo pipefail
build_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
exec "$build_dir/Wave.x86_64" --rendering-method forward_plus -- --quality
LAUNCH
chmod +x "$project_root/builds/linux/Wave-quality.sh"
printf '@echo off\r\ncd /d "%%~dp0"\r\nWave.exe --rendering-method forward_plus -- --quality\r\n' > "$project_root/builds/windows/Wave-quality.cmd"
printf 'Builds exported to %s/builds (ship each entire platform folder).\n' "$project_root"
