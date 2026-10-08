"""Audit frame CSVs and align slow intervals with read-only hardware snapshots."""

import argparse
from bisect import bisect_right
import csv
import json
import math
from pathlib import Path


def analyze(route_root):
    data = route_root / 'data/godot/app_userdata/Wave'
    if not data.exists():
        data = route_root  # Archived evidence keeps streaming.json beside performance/.
    route = json.loads((data / 'streaming.json').read_text())
    telemetry_path = route_root / 'hardware.jsonl'
    samples = [json.loads(line) for line in telemetry_path.read_text().splitlines()] if telemetry_path.exists() else []
    sample_times = [sample['unix_seconds'] for sample in samples]
    reports, spikes, all_frames, gaps = [], [], [], []
    previous_end = None
    clock_anchors_complete = True
    for path in sorted((data / 'performance').glob('*.json')):
        report = json.loads(path.read_text())
        anchor = report.get('capture_started_unix_seconds')
        anchor_valid = isinstance(anchor, (int, float)) and math.isfinite(anchor)
        clock_anchors_complete &= anchor_valid
        if not anchor_valid:
            anchor = None
        if anchor is not None and previous_end is not None:
            gaps.append({'before_capture': path.name, 'seconds': anchor - previous_end})
        previous_end = anchor + report['duration_seconds'] if anchor is not None else None
        with path.with_name(path.stem + '-frames.csv').open() as frame_csv:
            rows = list(csv.DictReader(frame_csv))
        frames = [float(row['frame_ms']) for row in rows]
        if not frames or len(frames) != report['frames']:
            raise ValueError(f'incomplete frame CSV: {path}')
        elapsed = 0.0
        for index, (row, frame) in enumerate(zip(rows, frames)):
            elapsed += frame / 1000
            if (not math.isfinite(frame) or frame <= 0 or int(row['frame']) != index
                    or not math.isfinite(float(row['elapsed_seconds']))
                    or abs(float(row['elapsed_seconds']) - elapsed) > 0.01):
                raise ValueError(f'invalid frame chronology: {path}')
        if abs(sum(frames) / 1000 - report['duration_seconds']) > 0.01:
            raise ValueError(f'frame duration mismatch: {path}')
        if abs(max(frames) - report['slowest_frame_ms']) > 0.002:
            raise ValueError(f'worst frame mismatch: {path}')
        focus = report['window_focus']
        if focus['focused_frames'] + focus['unfocused_frames'] != len(frames):
            raise ValueError(f'focus count mismatch: {path}')
        runs = focus.get('runs', [])
        starts = [run['first_frame'] for run in runs]
        for row in rows:
            if float(row['frame_ms']) <= 50:
                continue
            index = bisect_right(starts, int(row['frame'])) - 1
            focused = runs[index]['focused'] if index >= 0 else None
            wall_time = anchor + float(row['elapsed_seconds']) if anchor is not None else None
            sample_index = bisect_right(sample_times, wall_time) - 1 if wall_time is not None else -1
            nearest = samples[sample_index] if sample_index >= 0 else None
            spikes.append({'capture': path.name, **row, 'focused_at_interval_end': focused,
                           'telemetry_age_seconds': wall_time - nearest['unix_seconds'] if nearest else None,
                           'hardware_sample': nearest})
        reports.append({'capture': path.name, 'frames': len(frames),
                        'duration_seconds': report['duration_seconds'],
                        'fps_limit': report.get('fps_limit'), 'vsync_mode': report.get('vsync_mode'),
                        'focused_frames': focus['focused_frames'],
                        'unfocused_frames': focus['unfocused_frames']})
        all_frames.extend(frames)
    ordered = sorted(all_frames)
    if not ordered:
        raise ValueError('no frame captures')
    tail = ordered[-math.ceil(len(ordered) * 0.01):]
    sensors = {}
    for sample in samples:
        for name, value in sample['sensors'].items():
            if value is not None and value.isdigit():
                sensors.setdefault(name, []).append(int(value))
    p99 = ordered[math.ceil(len(ordered) * 0.99) - 1]
    unfocused = sum(report['unfocused_frames'] for report in reports)
    captured = sum(report['duration_seconds'] for report in reports)
    return {'scope': 'all intervals retained, including focus loss; telemetry is 1 Hz '
                     'and aligned by wall-clock anchor, not proof of spike causality; '
                     'captures rotate at 180 seconds, gaps are reported',
            'route_passed': route['route_passed'], 'legs': len(route['legs']),
            'requested_duration_seconds': route.get('requested_duration_seconds', 0),
            'route_duration_seconds': route.get('actual_duration_seconds'),
            'captured_seconds': captured,
            'uncaptured_route_seconds': max(0, route.get('actual_duration_seconds', captured) - captured),
            'frames': len(ordered), 'average_fps': len(ordered) * 1000 / sum(ordered),
            'p99_frame_ms': p99, 'slowest_frame_ms': ordered[-1],
            'one_percent_low_fps': 1000 / (sum(tail) / len(tail)),
            'frames_over_33_33_ms': sum(frame > 33.33 for frame in ordered),
            'frames_over_50_ms': len(spikes), 'unfocused_frames': unfocused,
            'capture_boundary_gaps': gaps,
            'clock_anchors_complete': clock_anchors_complete,
            'pacing_gate_passed': route['route_passed'] and unfocused == 0 and p99 <= 1000 / 30 and not spikes
                                  and clock_anchors_complete and all(0 <= gap['seconds'] <= 0.05 for gap in gaps),
            'captures': reports, 'hardware_samples': len(samples),
            'sensor_ranges': {name: {'min': min(values), 'max': max(values)}
                              for name, values in sensors.items()}, 'spikes': spikes}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('route_root', type=Path)
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    result = analyze(args.route_root)
    args.output.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({key: value for key, value in result.items()
                      if key not in ['spikes', 'sensor_ranges']}, indent=2))
