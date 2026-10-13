"""Read-only Linux telemetry outside the game's main thread (one sample/second)."""

import argparse
import json
import os
from pathlib import Path
import subprocess
import select
import sys
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
        paths += list(card.glob('gt_*freq_mhz'))
    paths += list(Path('/sys/class/hwmon').glob('hwmon*/temp*_input'))
    paths += list(Path('/sys/devices/system/cpu').glob('cpu[0-9]*/cpufreq/scaling_cur_freq'))
    return sorted(set(paths))


def sensor_worker():
    """A driver read can stall; keep it outside the monitor and game processes."""
    for line in sys.stdin:
        print(json.dumps(read(json.loads(line))), flush=True)


class SensorSampler:
    def __init__(self, paths, timeout=.15):
        self.paths = [str(path) for path in paths]
        self.timeout = timeout
        self.values = dict.fromkeys(self.paths)
        self.sampled_at = {}
        self.unavailable = {}
        self.pending = None
        self.cursor = 0
        self.worker = None

    def close(self):
        if self.worker is not None:
            self.worker.kill()
            self.worker.stdin.close()
            self.worker.stdout.close()
            try:
                self.worker.wait(timeout=.05)
            except subprocess.TimeoutExpired:
                # A kernel driver may delay even SIGKILL; never wait for it here.
                pass
            self.worker = None

    def collect(self, budget=.1):
        deadline = time.monotonic() + budget
        visited = 0
        while self.paths and time.monotonic() < deadline:
            if self.pending is not None:
                if select.select([self.worker.stdout], [], [], min(.01, max(0, deadline - time.monotonic())))[0]:
                    try:
                        self.values[self.pending] = json.loads(self.worker.stdout.readline())
                        self.sampled_at[self.pending] = time.time()
                    except (ValueError, OSError):
                        self.unavailable[self.pending] = 'reader exited'
                        self.close()
                    self.pending = None
                    visited += 1
                elif time.monotonic() - self.requested_at >= self.timeout:
                    self.unavailable[self.pending] = 'driver read exceeded timeout'
                    self.close()
                    self.pending = None
                    visited += 1
                else:
                    continue
            if visited >= len(self.paths):
                break
            path = self.paths[self.cursor]
            self.cursor = (self.cursor + 1) % len(self.paths)
            if path in self.unavailable:
                visited += 1
                continue
            if self.worker is None:
                self.worker = subprocess.Popen([sys.executable, __file__, '--sensor-worker'],
                                               stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                               stderr=subprocess.DEVNULL, text=True)
                startup_grace = .25
            else:
                startup_grace = 0
            self.worker.stdin.write(json.dumps(path) + '\n')
            self.worker.stdin.flush()
            self.pending = path
            self.requested_at = time.monotonic() + startup_grace
        return self.values.copy()


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
    sampler = SensorSampler(paths)
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
                       'sensors': sampler.collect(),
                       'sensor_sampled_at': sampler.sampled_at.copy(),
                       'sensor_unavailable': sampler.unavailable.copy(),
                       'top_cpu': sorted(busy, key=lambda item: item['cpu_percent_one_core'],
                                         reverse=True)[:8],
                       'game_status_memory': {key: value.strip() for line in (read(f'/proc/{process.pid}/status') or '').splitlines() if ':' in line for key, value in [line.split(':', 1)] if key in ['VmRSS', 'VmHWM', 'VmSwap']},
                       'game_cpu_percent_one_core': next(
                           (item['cpu_percent_one_core'] for item in busy
                            if item['pid'] == process.pid), None)}
                output.write(json.dumps(row) + '\n')
                output.flush()
                previous, previous_time = current, now
                try:
                    return process.wait(timeout=max(.01, 1.0 - (time.monotonic() - now)))
                except subprocess.TimeoutExpired:
                    pass
    finally:
        sampler.close()
        if process.poll() is None:
            process.terminate()
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()


if __name__ == '__main__':
    if sys.argv[1:] == ['--sensor-worker']:
        sensor_worker()
    else:
        raise SystemExit(main())
