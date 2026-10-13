"""Audit raw pilot-city capture files without hiding unfocused or slow frames."""
import argparse
import json
from pathlib import Path


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
        captured_sections = []
        for capture in sorted(folder.glob('data/**/performance/*.json')):
            item = json.loads(capture.read_text())
            focus = item['window_focus']
            gpu = item['gpu'].lower()
            expected_gpu = ('radeon' in gpu or 'amd' in gpu) if '-radeon-' in folder.name else 'intel' in gpu
            route_ok = all(result['arrived'] and result['ground_ratio'] > .99 for result in driving['results'])
            metadata = item.get('benchmark', {})
            leg, section = metadata.get('leg'), metadata.get('section')
            valid_section = (type(leg) is int and type(section) is int
                             and leg >= 0 and 0 <= section < sections_per_tour)
            result_index = leg * sections_per_tour + section if valid_section else -1
            valid_section &= 0 <= result_index < len(driving['results'])
            if valid_section:
                captured_sections.append(result_index)
            result = driving['results'][result_index] if valid_section else {}
            wall_seconds = result.get('wall_seconds')
            full_capture = wall_seconds is not None and abs(item['duration_seconds'] - wall_seconds) <= .2
            full_capture &= 0 < item['duration_seconds'] < 179.9
            item['acceptance'] = {
                'route_completed': bool(driving['results']) and route_ok, 'expected_gpu': expected_gpu,
                'exported_package': driving.get('package') is True,
                'expected_preset': driving['preset'] == ('medium' if '-radeon-' in folder.name else 'economy'),
                'compatibility_renderer': item.get('renderer') == 'gl_compatibility',
                'expected_window_resolution': item.get('window_size') == ('(1280, 720)' if '-radeon-' in folder.name else '(854, 480)'),
                'all_intervals_focused': focus['unfocused_frames'] == 0,
                'valid_route_section': valid_section,
                'whole_leg_captured': full_capture,
                'p95_within_30fps': item['p95_frame_ms'] <= 1000 / 30,
                'p99_within_30fps': item['p99_frame_ms'] <= 1000 / 30,
                'one_percent_low_at_least_30': item['one_percent_low_fps'] >= 30,
                'no_frames_over_50ms': item['frames_over_50_ms'] == 0,
                'no_frames_over_100ms': item['slowest_frame_ms'] <= 100,
            }
            item['passes_numeric_gate'] = all(item['acceptance'].values())
            captures.append(item)
        telemetry = [json.loads(line) for line in (folder / 'hardware.jsonl').read_text().splitlines()]
        memory = [row.get('game_status_memory', {}) for row in telemetry]
        rss = [int(item['VmRSS'].split()[0]) * 1024 for item in memory if 'VmRSS' in item]
        report = {'name': folder.name, 'execution_exit_code': int((folder / 'exit-code.txt').read_text()) if (folder / 'exit-code.txt').exists() else 0, 'driving': driving, 'captures': captures,
                  'peak_observed_rss_bytes': max(rss) if rss else None,
                  'passes_numeric_gate': sections_per_tour > 0 and len(captures) >= sections_per_tour and len(captures) % sections_per_tour == 0
                  and len(captures) == len(driving['results'])
                  and sorted(captured_sections) == list(range(len(driving['results'])))
                  and all(item['passes_numeric_gate'] for item in captures)}
        report['passes_numeric_gate'] &= report['execution_exit_code'] == 0
        requires_long_session = folder.name.endswith('-long')
        if requires_long_session or driving['long_session']:
            report['passes_numeric_gate'] &= (driving['long_session'] is True
                                              and driving['session_seconds'] >= 600)
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
