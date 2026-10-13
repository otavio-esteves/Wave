import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'scripts/tools'))
from analyze_pilot_profile import analyze


class ProfileAnalysisTest(unittest.TestCase):
    def report(self):
        rows = []
        for case, phase, frames in [('baseline', 'initial', 20), ('no-3d', 'ablation', 60), ('baseline', 'after-no-3d', 40)]:
            rows.append({'view': 113, 'case': case, 'phase': phase, 'frames': frames, 'duration_seconds': 1,
                         'p99_frame_ms': 1000 / frames, 'unfocused_frames': frames, 'samples': []})
        return {'debug_build': False, 'gpu': 'Mesa Intel HD Graphics 4400', 'results': rows}

    def test_pools_control_frames_and_preserves_unfocused_intervals(self):
        row = analyze(self.report())['comparisons'][0]
        self.assertEqual(row['baseline_fps_pooled'], 30)
        self.assertAlmostEqual(row['mean_frame_reduction_percent'], 50)
        self.assertEqual(row['baseline_unfocused_percent'], 100)
        self.assertEqual(row['ablation_unfocused_percent'], 100)
        self.assertAlmostEqual(row['control_frame_time_drift_percent'], 75)
        self.assertIsNone(row['ablation_monitors_mean']['draw_calls'])

    def test_rejects_unexpected_gpu_and_debug_build(self):
        report = self.report()
        report['gpu'] = 'AMD Radeon R7 M260'
        with self.assertRaises(ValueError):
            analyze(report)
        report = self.report()
        report['debug_build'] = True
        with self.assertRaises(ValueError):
            analyze(report)

    def test_rejects_missing_or_mismatched_controls(self):
        report = self.report()
        report['results'].pop()
        with self.assertRaises(ValueError):
            analyze(report)
        report = self.report()
        report['results'][2]['view'] = 114
        with self.assertRaises(ValueError):
            analyze(report)

    def test_rejects_empty_capture(self):
        report = self.report()
        report['results'][1]['frames'] = 0
        with self.assertRaises(ValueError):
            analyze(report)


if __name__ == '__main__':
    unittest.main()
