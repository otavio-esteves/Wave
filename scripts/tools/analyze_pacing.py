"""Audit frame CSVs and align slow intervals with read-only hardware snapshots."""

import argparse
from bisect import bisect_right
import csv
import json
import math
from pathlib import Path


COVERAGE_TOLERANCE_SECONDS = .05
CLOCK_PRECISION_SECONDS = .002


def finite_number(value):
    return type(value) in (int, float) and math.isfinite(value)


def route_coverage(route, reports, gaps):
    """Certify the complete declared interval, including its first/last frame."""
    duration = route.get('actual_duration_seconds')
    requested = route.get('requested_duration_seconds', 0)
    started = route.get('route_started_unix_seconds')
    finished = route.get('route_finished_unix_seconds')
    duration_valid = finite_number(duration) and duration > 0
    interval_valid = (finite_number(started) and finite_number(finished)
                      and started > 0 and finished > started)
    reasons = []
    if route.get('capture_enabled') is not True:
        reasons.append('route does not declare an enabled capture')
    legs = route.get('legs')
    if not isinstance(legs, list) or not legs or any(
            not isinstance(leg, dict) or leg.get('passed') is not True for leg in legs):
        reasons.append('route leg results are missing or incomplete')
    if not duration_valid:
        reasons.append('route duration must be finite and positive')
    if not finite_number(requested) or requested < 0:
        reasons.append('requested duration must be finite and nonnegative')
    elif duration_valid and duration + CLOCK_PRECISION_SECONDS < requested:
        reasons.append('route ended before its requested duration')
    if not interval_valid:
        reasons.append('route start/end clock anchors are missing or invalid')
    elif duration_valid and abs(finished - started - duration) > CLOCK_PRECISION_SECONDS:
        reasons.append('route clock interval disagrees with its monotonic duration')
    captured = sum(report['duration_seconds'] for report in reports)
    difference = duration - captured if duration_valid else None
    if difference is not None and abs(difference) > COVERAGE_TOLERANCE_SECONDS:
        reasons.append('captured duration does not cover the complete route')
    anchors_complete = all(report['capture_started_unix_seconds'] is not None for report in reports)
    start_gap, end_gap = None, None
    covered = None
    missing = max(0, difference) if difference is not None else None
    if not anchors_complete:
        reasons.append('capture clock anchors are missing or invalid')
    elif interval_valid and reports:
        start_gap = reports[0]['capture_started_unix_seconds'] - started
        end_gap = finished - (reports[-1]['capture_started_unix_seconds']
                              + reports[-1]['duration_seconds'])
        for label, gap in [('initial', start_gap), ('final', end_gap)]:
            if not -CLOCK_PRECISION_SECONDS <= gap <= COVERAGE_TOLERANCE_SECONDS:
                reasons.append(f'{label} capture boundary lies outside the route coverage budget')
        # Use the union, clipped to the route interval. Tiny timestamp overlaps
        # must not cancel a cumulative series of genuinely unmeasured gaps.
        covered = 0.0
        covered_until = started
        for report in reports:
            begin = max(started, report['capture_started_unix_seconds'])
            end = min(finished, report['capture_started_unix_seconds'] + report['duration_seconds'])
            covered += max(0, end - max(begin, covered_until))
            covered_until = max(covered_until, end)
        missing = max(0, finished - started - covered)
        if missing > COVERAGE_TOLERANCE_SECONDS:
            reasons.append('capture intervals leave too much of the route unmeasured')
    if any(not -CLOCK_PRECISION_SECONDS <= gap['seconds'] <= COVERAGE_TOLERANCE_SECONDS
           for gap in gaps):
        reasons.append('captures overlap or leave an unmeasured interval')
    return {'coverage_complete': not reasons, 'coverage_failure_reasons': reasons,
            'coverage_tolerance_seconds': COVERAGE_TOLERANCE_SECONDS,
            'clock_precision_tolerance_seconds': CLOCK_PRECISION_SECONDS,
            'route_started_unix_seconds': started, 'route_finished_unix_seconds': finished,
            'capture_start_gap_seconds': start_gap, 'capture_end_gap_seconds': end_gap,
            'covered_route_seconds': covered, 'uncaptured_route_seconds': missing,
            'capture_duration_discrepancy_seconds': difference,
            'overcaptured_route_seconds': max(0, captured - covered) if covered is not None else (
                max(0, -difference) if difference is not None else None)}


def analyze(route_root):
    data = route_root / 'data/godot/app_userdata/Wave'
    if not data.exists():
        data = route_root  # Archived evidence keeps streaming.json beside performance/.
    route = json.loads((data / 'streaming.json').read_text())
    if not isinstance(route, dict):
        raise ValueError('route report must be a JSON object')
    telemetry_path = route_root / 'hardware.jsonl'
    samples = [json.loads(line) for line in telemetry_path.read_text().splitlines()] if telemetry_path.exists() else []
    sample_times = [sample['unix_seconds'] for sample in samples]
    reports, spikes, all_frames, gaps = [], [], [], []
    previous_end = None
    clock_anchors_complete = True
    captures = []
    for path in (data / 'performance').glob('*.json'):
        report = json.loads(path.read_text())
        if not isinstance(report, dict):
            raise ValueError(f'capture report must be a JSON object: {path}')
        captures.append((path, report))
    # Names are not evidence of chronology. Clock anchors also expose duplicate
    # or overlapping files left behind by an interrupted capture.
    captures.sort(key=lambda item: (item[1].get('capture_started_unix_seconds')
                                    if finite_number(item[1].get('capture_started_unix_seconds'))
                                    else math.inf, item[0].name))
    for path, report in captures:
        anchor = report.get('capture_started_unix_seconds')
        anchor_valid = finite_number(anchor) and anchor > 0
        clock_anchors_complete &= anchor_valid
        if not anchor_valid:
            anchor = None
        if not finite_number(report.get('duration_seconds')) or report['duration_seconds'] <= 0:
            raise ValueError(f'invalid capture duration: {path}')
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
        if any(type(focus.get(key)) is not int or focus[key] < 0
               for key in ['focused_frames', 'unfocused_frames']) or (
                focus['focused_frames'] + focus['unfocused_frames'] != len(frames)):
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
                        'capture_started_unix_seconds': anchor,
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
    coverage = route_coverage(route, reports, gaps)
    one_percent_low = 1000 / (sum(tail) / len(tail))
    return {'scope': 'all intervals retained, including focus loss; telemetry is 1 Hz '
                     'and aligned by wall-clock anchor, not proof of spike causality; '
                     'captures rotate at 180 seconds; complete route coverage requires '
                     'route clock anchors and a total unmeasured budget of 50 ms',
            'route_passed': route.get('route_passed') is True,
            'legs': len(route['legs']) if isinstance(route.get('legs'), list) else 0,
            'requested_duration_seconds': route.get('requested_duration_seconds', 0),
            'route_duration_seconds': route.get('actual_duration_seconds'),
            'captured_seconds': captured,
            **coverage,
            'frames': len(ordered), 'average_fps': len(ordered) * 1000 / sum(ordered),
            'p99_frame_ms': p99, 'slowest_frame_ms': ordered[-1],
            'one_percent_low_fps': one_percent_low,
            'frames_over_33_33_ms': sum(frame > 33.33 for frame in ordered),
            'frames_over_50_ms': len(spikes), 'unfocused_frames': unfocused,
            'capture_boundary_gaps': gaps,
            'clock_anchors_complete': clock_anchors_complete,
            'pacing_gate_passed': route.get('route_passed') is True and unfocused == 0 and p99 <= 1000 / 30 and not spikes
                                  and one_percent_low >= 30 and clock_anchors_complete and coverage['coverage_complete'],
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
