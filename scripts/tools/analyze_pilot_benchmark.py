"""Audit raw pilot-city capture files without hiding unfocused or slow frames."""
import argparse
import csv
import json
import math
from pathlib import Path


def covers_section(item: dict, result: dict) -> bool:
    duration = item.get('duration_seconds')
    if not isinstance(duration, (int, float)) or not 0 < duration < 179.9:
        return False
    started = result.get('section_started_unix_seconds')
    finished = result.get('section_finished_unix_seconds')
    section_duration = result.get('section_duration_seconds')
    capture_started = item.get('capture_started_unix_seconds')
    if started is None and finished is None and section_duration is None:
        # Retain duration diagnostics for archived pre-segment runs.
        wall = result.get('wall_seconds')
        return isinstance(wall, (int, float)) and abs(duration - wall) <= .2
    time_values = (started, finished, section_duration, capture_started)
    return (all(type(value) in (int, float) and math.isfinite(value) for value in time_values)
            and 0 < started < finished and section_duration > 0
            and abs(finished - started - section_duration) <= .002
            and abs(duration - section_duration) <= .002
            and abs(capture_started - started) <= .002)


def matches_frame_csv(path: Path, capture: dict) -> bool:
    frames = []
    elapsed = 0.0
    try:
        with path.with_name(path.stem + '-frames.csv').open(newline='') as stream:
            for index, row in enumerate(csv.DictReader(stream)):
                frame = float(row['frame_ms'])
                frame_end = float(row['elapsed_seconds'])
                elapsed += frame / 1000
                if (not math.isfinite(frame) or frame <= 0 or int(row['frame']) != index
                        or not math.isfinite(frame_end) or abs(elapsed - frame_end) > .002):
                    return False
                frames.append(frame)
        if (not frames or len(frames) != capture['frames']
                or abs(elapsed - capture['duration_seconds']) > .002):
            return False
        frames.sort()
        tail_size = math.ceil(len(frames) * .01)
        metrics = {
            'p95_frame_ms': frames[math.ceil(len(frames) * .95) - 1],
            'p99_frame_ms': frames[math.ceil(len(frames) * .99) - 1],
            'slowest_frame_ms': frames[-1],
            'one_percent_low_fps': 1000 * tail_size / sum(frames[-tail_size:]),
        }
        return (capture['frames_over_50_ms'] == sum(frame > 50 for frame in frames)
                and all(math.isclose(capture[key], value, abs_tol=.002)
                        for key, value in metrics.items()))
    except (OSError, KeyError, TypeError, ValueError):
        return False


def summarize(root: Path) -> dict:
    context = json.loads((root / 'context.json').read_text())
    passes = []
    for folder in sorted(path for path in root.iterdir() if path.is_dir()):
        files = list(folder.glob('data/**/pilot-benchmark.json'))
        if not files:
            continue
        driving = json.loads(files[0].read_text())
        captures = []
        sections_per_tour = int(driving.get('sections_per_tour', 3))
        section_start = int(driving.get('section_start', 0))
        results = driving['results']
        route_ok = bool(results) and all(result['arrived'] and result['ground_ratio'] > .99 for result in results)
        captured_sections = []
        radeon = '-radeon-' in folder.name
        expected_model = 'radeon r7 m260' if radeon else 'hd graphics 4400'
        expected_preset = 'medium' if radeon else 'economy'
        for capture in sorted(folder.glob('data/**/performance/*.json')):
            item = json.loads(capture.read_text())
            focus = item['window_focus']
            gpu = item['gpu'].lower()
            metadata = item.get('benchmark', {})
            leg, section = metadata.get('leg'), metadata.get('section')
            valid_section = (type(leg) is int and type(section) is int
                             and leg >= 0 and section_start <= section < sections_per_tour)
            result_index = leg * sections_per_tour + section - section_start if valid_section else -1
            valid_section &= 0 <= result_index < len(results)
            if valid_section:
                captured_sections.append(result_index)
            result = results[result_index] if valid_section else {}
            item['acceptance'] = {
                'route_completed': route_ok, 'expected_gpu': expected_model in gpu,
                'exported_package': driving.get('package') is True,
                'native_release': driving.get('debug_build') is False and item.get('debug_build') is False,
                'production_proxy_ranges': metadata.get('unbounded_building_proxies', False) is False,
                'expected_preset': driving['preset'] == expected_preset and item.get('preset') == expected_preset,
                'compatibility_renderer': item.get('renderer') == 'gl_compatibility',
                'expected_window_resolution': item.get('window_size') == ('(1280, 720)' if radeon else '(854, 480)'),
                'all_intervals_focused': focus['unfocused_frames'] == 0 and focus.get('focused_frames') == item.get('frames'),
                'valid_route_section': valid_section,
                'whole_leg_captured': covers_section(item, result),
                'anchored_route_section': result.get('section_started_unix_seconds') is not None,
                'raw_frames_match_capture': matches_frame_csv(capture, item),
                'p95_within_30fps': item['p95_frame_ms'] <= 1000 / 30,
                'p99_within_30fps': item['p99_frame_ms'] <= 1000 / 30,
                'one_percent_low_at_least_30': item['one_percent_low_fps'] >= 30,
                'no_frames_over_50ms': item['frames_over_50_ms'] == 0,
                'no_frames_over_100ms': item['slowest_frame_ms'] <= 100,
            }
            item['passes_numeric_gate'] = all(item['acceptance'].values())
            captures.append(item)
        telemetry_path = folder / 'hardware.jsonl'
        telemetry = [json.loads(line) for line in telemetry_path.read_text().splitlines()] if telemetry_path.exists() else []
        memory = [row.get('game_status_memory', {}) for row in telemetry]
        rss = [int(item['VmRSS'].split()[0]) * 1024 for item in memory if 'VmRSS' in item]
        exit_path = folder / 'exit-code.txt'
        status = int(exit_path.read_text()) if exit_path.exists() else None
        report = {'name': folder.name, 'execution_exit_code': status, 'driving': driving, 'captures': captures,
                  'peak_observed_rss_bytes': max(rss) if rss else None,
                  'passes_numeric_gate': section_start == 0 and sections_per_tour > 0 and len(captures) >= sections_per_tour and len(captures) % sections_per_tour == 0
                  and len(captures) == len(results)
                  and sorted(captured_sections) == list(range(len(results)))
                  and all(item['passes_numeric_gate'] for item in captures)}
        report['passes_numeric_gate'] &= status == 0
        if report['passes_numeric_gate']:
            report['passes_numeric_gate'] = all(
                abs(results[index]['section_started_unix_seconds']
                    - results[index - 1]['section_finished_unix_seconds']) <= .002
                for index in range(1, len(results)) if index % sections_per_tour)
        requires_long_session = folder.name.endswith('-long')
        if requires_long_session or driving['long_session']:
            report['passes_numeric_gate'] = (report['passes_numeric_gate']
                                             and driving['long_session'] is True
                                             and driving['session_seconds'] >= 600
                                             and sum(result['section_duration_seconds'] for result in results) >= 600)
        passes.append(report)
    required = {f'after-{gpu}-{number}' for gpu in ['intel', 'radeon'] for number in [1, 2, 3, 'long']}
    accepted = {item['name'] for item in passes if item['passes_numeric_gate']}
    return {'context': context, 'passes': passes,
            'controlled_rendered_gate_passed': context['exclusive_use_declared'] and required <= accepted,
            'product_certified': False,
            'remaining_product_validation': ['8 GB memory target', 'human driving and art review', 'native Windows']}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('folder', type=Path)
    args = parser.parse_args()
    report = summarize(args.folder)
    (args.folder / 'summary.json').write_text(json.dumps(report, indent=2) + '\n')
    for item in report['passes']:
        for capture in item['captures']:
            print(f"{item['name']}: {capture['average_fps']:.1f} FPS; P99 {capture['p99_frame_ms']:.2f} ms; "
                  f"1% low {capture['one_percent_low_fps']:.1f}; gate={capture['passes_numeric_gate']}")
    print('Controlled rendered gate:', report['controlled_rendered_gate_passed'])
