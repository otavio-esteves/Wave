"""Compare diagnostic ablations with the complete view measured on either side."""

import argparse
import json
from pathlib import Path


def mean_monitor(capture, name):
    values = [sample[name] for sample in capture['samples'] if name in sample]
    return sum(values) / len(values) if values else None


def analyze(report, expected_gpu='intel'):
    if report['debug_build']:
        raise ValueError('This analysis requires the native release diagnostic build')
    if expected_gpu not in report['gpu'].lower():
        raise ValueError(f"Expected {expected_gpu}, recorded {report['gpu']}")
    results = report['results']
    comparisons = []
    for index, capture in enumerate(results):
        if capture['phase'] != 'ablation':
            continue
        if index == 0 or index + 1 == len(results):
            raise ValueError('Ablation must have a baseline before and after')
        controls = [results[index - 1], results[index + 1]]
        if any(row['case'] != 'baseline' or row['view'] != capture['view'] for row in controls):
            raise ValueError('Adjacent controls must be the complete, matching view')
        if any(row['frames'] <= 0 or row['duration_seconds'] <= 0 for row in controls + [capture]):
            raise ValueError('A capture cannot be empty')
        baseline_fps = sum(row['frames'] for row in controls) / sum(row['duration_seconds'] for row in controls)
        ablation_fps = capture['frames'] / capture['duration_seconds']
        baseline_ms = 1000 / baseline_fps
        before_ms, after_ms = [1000 * row['duration_seconds'] / row['frames'] for row in controls]
        comparisons.append({
            'view': capture['view'], 'case': capture['case'],
            'baseline_fps_pooled': baseline_fps, 'ablation_fps': ablation_fps,
            'baseline_mean_frame_ms': baseline_ms, 'ablation_mean_frame_ms': 1000 / ablation_fps,
            'mean_frame_reduction_percent': 100 * (baseline_ms - 1000 / ablation_fps) / baseline_ms,
            'control_frame_time_drift_percent': 100 * abs(before_ms - after_ms) / baseline_ms,
            'baseline_p99_ms': [row['p99_frame_ms'] for row in controls],
            'ablation_p99_ms': capture['p99_frame_ms'],
            'baseline_unfocused_percent': 100 * sum(row['unfocused_frames'] for row in controls) / sum(row['frames'] for row in controls),
            'ablation_unfocused_percent': 100 * capture['unfocused_frames'] / capture['frames'],
            'ablation_monitors_mean': {name: mean_monitor(capture, name) for name in ['process_ms', 'physics_ms', 'draw_calls', 'objects', 'primitives']},
            'control_monitors_mean': [{name: mean_monitor(row, name) for name in ['process_ms', 'physics_ms', 'draw_calls', 'objects', 'primitives']} for row in controls],
        })
    return {'scope': 'Native static diagnostic, all frames included; controls quantify drift, not exclusive use. No causal/product certification.',
            'gpu': report['gpu'], 'debug_build': report['debug_build'], 'comparisons': comparisons}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('summary', type=Path)
    parser.add_argument('--gpu', default='intel')
    args = parser.parse_args()
    analysis = analyze(json.loads(args.summary.read_text()), args.gpu)
    args.summary.with_name('analysis.json').write_text(json.dumps(analysis, indent=2) + '\n')
    for item in analysis['comparisons']:
        print(f"view {item['view']} {item['case']}: {item['baseline_fps_pooled']:.1f} -> {item['ablation_fps']:.1f} FPS; "
              f"mean frame reduction {item['mean_frame_reduction_percent']:.1f}%; controls drift {item['control_frame_time_drift_percent']:.1f}%")
