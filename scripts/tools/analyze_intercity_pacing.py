"""Compare intercity capture on/off using the same minimal frame observer."""
import argparse
from bisect import bisect_right
import csv
import json
import math
from pathlib import Path


def analyze_run(root):
    data = root / 'data/godot/app_userdata/Wave'
    report = json.loads((data / 'pacing.json').read_text())
    route = json.loads((data / 'intercity.json').read_text())
    with (data / 'pacing-frames.csv').open() as frame_csv:
        rows = list(csv.DictReader(frame_csv))
    events = route['streaming']['events']
    hlod = report.get('hlod', {})
    hardware = [json.loads(line) for line in (root / 'hardware.jsonl').read_text().splitlines()]
    times = [sample['unix_seconds'] for sample in hardware]
    if [leg['leg'] for leg in report['legs']] != ['outward', 'return'] or set(
            row['leg'] for row in rows) != {'outward', 'return'}:
        raise ValueError('incomplete round trip')
    legs = []
    for leg in report['legs']:
        selected = [row for row in rows if row['leg'] == leg['leg']]
        if not selected or len(selected) != leg['frames']:
            raise ValueError('incomplete observer CSV')
        frames = [float(row['frame_ms']) for row in selected]
        ids = [int(row['process_frame']) for row in selected]
        if any(not math.isfinite(ms) or ms <= 0 for ms in frames) or any(
                right != left + 1 for left, right in zip(ids, ids[1:])):
            raise ValueError('invalid observer chronology')
        ordered = sorted(frames)
        tail = ordered[-math.ceil(len(frames) * .01):]
        metrics = {'average_fps': len(frames) * 1000 / sum(frames),
                   'p99_frame_ms': ordered[math.ceil(len(frames) * .99) - 1],
                   'slowest_frame_ms': max(frames),
                   'one_percent_low_fps': 1000 * len(tail) / sum(tail),
                   'frames_over_50_ms': sum(ms > 50 for ms in frames)}
        for key, value in metrics.items():
            if abs(value - leg[key]) > .002:
                raise ValueError(f'observer summary mismatch: {key}')
        unfocused = sum(row['focused'] != 'true' for row in selected)
        if unfocused != leg['unfocused_frames']:
            raise ValueError('observer focus mismatch')
        elapsed = 0
        spikes = []
        for row, ms in zip(selected, frames):
            elapsed += ms / 1000
            if ms <= 50:
                continue
            wall = leg['capture_started_unix_seconds'] + elapsed
            index = bisect_right(times, wall) - 1
            sample = hardware[index] if index >= 0 else None
            # A process interval includes work after the previous observation;
            # retain adjacent-frame candidates explicitly, never assert causality.
            nearby = [event for event in events
                      if abs(event['process_frame'] - int(row['process_frame'])) <= 1]
            nearby_hlod = [event for event in hlod.get('events', [])
                           if abs(event['process_frame'] - int(row['process_frame'])) <= 2]
            spikes.append({**row, 'elapsed_seconds': elapsed,
                           'nearby_streaming_events': nearby,
                           'nearby_hlod_events': nearby_hlod,
                           'hardware_sample': sample,
                           'telemetry_age_seconds': wall - sample['unix_seconds'] if sample else None})
        legs.append({'leg': leg['leg'], 'frames': len(frames),
                     'duration_seconds': sum(frames) / 1000,
                     'unfocused_frames': unfocused, **metrics, 'spikes': spikes})
    return {'run': root.name, 'capture_enabled': report['capture_enabled'],
            'gpu': report['gpu'], 'window_size': report['window_size'],
            'renderer': report['renderer'], 'graphics': report['graphics'],
            'fps_limit': report['fps_limit'], 'vsync_mode': report['vsync_mode'],
            'detail_enter_m': hlod.get('detail_enter_m'),
            'route_passed': route['failures'] == 0 and all(
                route[name]['arrived'] and route[name]['grounded'] for name in ['outward', 'return']),
            'legs': legs}


def analyze(root):
    runs = [analyze_run(path) for path in sorted(root.iterdir())
            if path.is_dir() and (path / 'data/godot/app_userdata/Wave/pacing.json').exists()]
    if not runs:
        raise ValueError('no completed diagnostic runs')
    baseline = runs[0]
    for run in runs:
        for key in ['gpu', 'window_size', 'renderer', 'graphics', 'fps_limit', 'vsync_mode']:
            if run[key] != baseline[key]:
                raise ValueError(f'incomparable settings: {key}')
    return {'scope': 'observer in both arms; adjacent process frames identify candidates, '
                     'not GPU attribution; 1 Hz hardware snapshots do not prove thermal causality; '
                     'six short sessions do not certify sustained performance', 'runs': runs}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('root', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    result = analyze(args.root)
    args.output.write_text(json.dumps(result, indent=2) + '\n')
    for run in result['runs']:
        for leg in run['legs']:
            print(run['run'], leg['leg'], {key: value for key, value in leg.items() if key != 'spikes'})
