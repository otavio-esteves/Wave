"""Synthetic audits verify that incomplete or invalid captures cannot certify a run."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('pilot_audit', Path(__file__).parents[1] / 'scripts/tools/analyze_pilot_benchmark.py')
audit = importlib.util.module_from_spec(spec)
spec.loader.exec_module(audit)


class PilotAuditTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.write(self.root / 'context.json', {'exclusive_use_declared': True})
        for gpu in ['intel', 'radeon']:
            for number in [1, 2, 3, 'long']:
                folder = self.root / f'after-{gpu}-{number}'
                folder.mkdir()
                (folder / 'hardware.jsonl').write_text(json.dumps({'game_status_memory': {'VmRSS': '1024 kB'}}) + '\n')
                self.write(folder / 'data/pilot-benchmark.json', {
                    'results': [{'arrived': True, 'ground_ratio': 1.0, 'wall_seconds': 75}] * 3,
                    'long_session': number == 'long', 'session_seconds': 700,
                    'preset': 'economy' if gpu == 'intel' else 'medium', 'package': True})
                for section in range(3):
                    self.write(folder / f'data/performance/{section}.json', {
                        'window_focus': {'unfocused_frames': 0}, 'gpu': gpu,
                        'renderer': 'gl_compatibility', 'window_size': '(854, 480)' if gpu == 'intel' else '(1280, 720)',
                        'duration_seconds': 75, 'benchmark': {'leg': 0, 'section': section}, 'p95_frame_ms': 20, 'p99_frame_ms': 25,
                        'one_percent_low_fps': 35, 'frames_over_50_ms': 0, 'slowest_frame_ms': 30})

    def write(self, path, item):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(item))

    def mutate(self, path, key, value):
        item = json.loads(path.read_text())
        item[key] = value
        self.write(path, item)

    def test_complete_controlled_runs_pass_without_claiming_product_certification(self):
        report = audit.summarize(self.root)
        self.assertTrue(report['controlled_rendered_gate_passed'])
        self.assertFalse(report['product_certified'])
        self.assertEqual(report['passes'][0]['peak_observed_rss_bytes'], 1048576)

    def test_bad_focus_gpu_tail_or_truncated_capture_fail(self):
        path = self.root / 'after-intel-1/data/performance/0.json'
        original = json.loads(path.read_text())
        for key, value in [('window_focus', {'unfocused_frames': 1}), ('gpu', 'radeon'),
                           ('window_size', '(640, 480)'), ('renderer', 'forward_plus'), ('p99_frame_ms', 40), ('one_percent_low_fps', 29),
                           ('frames_over_50_ms', 1), ('duration_seconds', 180), ('duration_seconds', 30)]:
            with self.subTest(key=key):
                self.write(path, original)
                self.mutate(path, key, value)
                self.assertFalse(audit.summarize(self.root)['controlled_rendered_gate_passed'])

    def test_missing_leg_fails(self):
        (self.root / 'after-intel-1/data/performance/2.json').unlink()
        self.assertFalse(audit.summarize(self.root)['controlled_rendered_gate_passed'])

    def test_short_long_session_uncontrolled_or_source_execution_fail(self):
        path = self.root / 'after-intel-long/data/pilot-benchmark.json'
        self.mutate(path, 'session_seconds', 599)
        self.assertFalse(audit.summarize(self.root)['controlled_rendered_gate_passed'])
        self.mutate(path, 'session_seconds', 700)
        self.mutate(path, 'package', False)
        self.assertFalse(audit.summarize(self.root)['controlled_rendered_gate_passed'])
        self.mutate(path, 'package', True)
        self.mutate(self.root / 'context.json', 'exclusive_use_declared', False)
        self.assertFalse(audit.summarize(self.root)['controlled_rendered_gate_passed'])


if __name__ == '__main__':
    unittest.main()
