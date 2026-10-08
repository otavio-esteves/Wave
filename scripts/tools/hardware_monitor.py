"""Read-only Linux telemetry outside the game's main thread (one sample/second)."""

import argparse
import json
import os
from pathlib import Path
import subprocess
import time


def read(path):
    try:
        return Path(path).read_text().strip()
    except OSError:
        return None


def discover():
    paths = list(Path('/sys/class/power_supply').glob('*/online'))
    paths += list(Path('/sys/class/power_supply').glob('*/status'))
    for card in Path('/sys/class/drm').glob('card[0-9]'):
        paths += [card / 'device' / key for key in
                  ['gpu_busy_percent', 'pp_dpm_sclk', 'pp_dpm_mclk',
                   'power_dpm_force_performance_level']]
        paths += list((card / 'device/hwmon').glob('hwmon*/temp1_input'))
    paths += list(Path('/sys/class/hwmon').glob('hwmon*/temp*_input'))
    paths += list(Path('/sys/devices/system/cpu').glob('cpu[0-9]*/cpufreq/scaling_cur_freq'))
    return sorted(set(paths))


def cpu_ticks():
    result = {}
    for directory in Path('/proc').glob('[0-9]*'):
        data = read(directory / 'stat')
        if data is None:
            continue
        try:
            # comm can contain spaces/parentheses. Never record command arguments.
            end = data.rfind(')')
            fields = data[end + 2:].split()
            result[int(directory.name)] = (int(fields[11]) + int(fields[12]),
                                           data[data.find('(') + 1:end], fields[19])
        except (ValueError, IndexError):
            continue
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', required=True)
    parser.add_argument('command', nargs=argparse.REMAINDER)
    args = parser.parse_args()
    command = args.command[1:] if args.command[:1] == ['--'] else args.command
    if not command:
        parser.error('a command is required after --')
    paths = discover()
    tick_rate = os.sysconf('SC_CLK_TCK')
    started = time.monotonic()
    previous_time = started
    previous = cpu_ticks()
    process = subprocess.Popen(command)
    try:
        with Path(args.output).open('x') as output:
            while True:
                now = time.monotonic()
                current = cpu_ticks()
                busy = []
                interval = now - previous_time
                if interval > 0:
                    for pid, (ticks, name, birth) in current.items():
                        old = previous.get(pid)
                        if old is not None and old[2] == birth:
                            percent = 100 * (ticks - old[0]) / tick_rate / interval
                            busy.append({'pid': pid, 'name': name,
                                         'cpu_percent_one_core': round(percent, 2)})
                row = {'unix_seconds': time.time(),
                       'elapsed_seconds': now - started, 'game_pid': process.pid,
                       'scope': 'read-only 1 Hz snapshots; CPU percent is per core; '
                                'not exclusive GPU timing or proof of thermal throttling',
                       'sensors': {str(path): read(path) for path in paths},
                       'top_cpu': sorted(busy, key=lambda item: item['cpu_percent_one_core'],
                                         reverse=True)[:8],
                       'game_cpu_percent_one_core': next(
                           (item['cpu_percent_one_core'] for item in busy
                            if item['pid'] == process.pid), None)}
                output.write(json.dumps(row) + '\n')
                output.flush()
                previous, previous_time = current, now
                try:
                    return process.wait(timeout=1.0)
                except subprocess.TimeoutExpired:
                    pass
    finally:
        if process.poll() is None:
            process.terminate()
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()


if __name__ == '__main__':
    raise SystemExit(main())
