"""Integrity checks for exported pacing evidence and the telemetry wrapper."""
import csv
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('pacing', ROOT / 'scripts/tools/analyze_pacing.py')
pacing = importlib.util.module_from_spec(spec)
spec.loader.exec_module(pacing)
monitor_spec = importlib.util.spec_from_file_location('monitor', ROOT / 'scripts/tools/hardware_monitor.py')
monitor = importlib.util.module_from_spec(monitor_spec)
monitor_spec.loader.exec_module(monitor)


class PacingEvidenceTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.data = self.root / 'data/godot/app_userdata/Wave'
        self.captures = self.data / 'performance'
        self.captures.mkdir(parents=True)
        self.route({'route_passed': True, 'legs': [{'passed': True}], 'capture_enabled': True,
                    'requested_duration_seconds': 0, 'actual_duration_seconds': .033,
                    'route_started_unix_seconds': 100, 'route_finished_unix_seconds': 100.033})

    def route(self, values):
        path = self.data / 'streaming.json'
        report = json.loads(path.read_text()) if path.exists() else {}
        report.update(values)
        path.write_text(json.dumps(report))

    def capture(self, name='001', anchor=100, frames=(16, 17), unfocused=0):
        report = {'frames': len(frames), 'duration_seconds': sum(frames) / 1000,
                  'slowest_frame_ms': max(frames), 'capture_started_unix_seconds': anchor,
                  'window_focus': {'focused_frames': len(frames) - unfocused,
                                   'unfocused_frames': unfocused, 'runs': []}}
        (self.captures / (name + '.json')).write_text(json.dumps(report))
        with (self.captures / (name + '-frames.csv')).open('w') as output:
            writer = csv.writer(output)
            writer.writerow(['frame', 'elapsed_seconds', 'frame_ms'])
            elapsed = 0
            for index, frame in enumerate(frames):
                elapsed += frame / 1000
                writer.writerow([index, elapsed, frame])

    def test_clean_capture_passes(self):
        self.capture()
        result = pacing.analyze(self.root)
        self.assertTrue(result['pacing_gate_passed'])
        self.assertTrue(result['coverage_complete'])
        self.assertEqual(result['coverage_failure_reasons'], [])

    def test_full_rotated_capture_passes_using_clock_order(self):
        self.capture('z-first')
        self.capture('a-last', anchor=100.033)
        self.route({'actual_duration_seconds': .066, 'route_finished_unix_seconds': 100.066})
        result = pacing.analyze(self.root)
        self.assertTrue(result['pacing_gate_passed'])
        self.assertEqual([item['capture'] for item in result['captures']],
                         ['z-first.json', 'a-last.json'])

    def test_tiny_capture_cannot_certify_a_ten_minute_route(self):
        self.capture()
        self.route({'requested_duration_seconds': 600, 'actual_duration_seconds': 600,
                    'route_finished_unix_seconds': 700})
        result = pacing.analyze(self.root)
        self.assertAlmostEqual(result['uncaptured_route_seconds'], 599.967)
        self.assertFalse(result['coverage_complete'])
        self.assertFalse(result['pacing_gate_passed'])

    def test_missing_first_or_last_capture_fails_even_without_internal_gaps(self):
        self.capture()
        for started, finished in [(99, 100.033), (100, 101.033)]:
            with self.subTest(started=started, finished=finished):
                self.route({'actual_duration_seconds': finished - started,
                            'route_started_unix_seconds': started,
                            'route_finished_unix_seconds': finished})
                result = pacing.analyze(self.root)
                self.assertEqual(result['capture_boundary_gaps'], [])
                self.assertFalse(result['pacing_gate_passed'])

    def test_overlapping_captures_cannot_compensate_for_missing_route_time(self):
        self.capture()
        self.capture('002', anchor=100.020)
        self.route({'actual_duration_seconds': .066, 'route_finished_unix_seconds': 100.066})
        result = pacing.analyze(self.root)
        self.assertAlmostEqual(result['captured_seconds'], .066)
        self.assertLess(result['capture_boundary_gaps'][0]['seconds'], -.002)
        self.assertFalse(result['pacing_gate_passed'])

    def test_route_interval_must_agree_with_monotonic_duration(self):
        self.capture()
        self.route({'route_finished_unix_seconds': 700})
        result = pacing.analyze(self.root)
        self.assertFalse(result['pacing_gate_passed'])
        self.assertIn('route clock interval disagrees with its monotonic duration',
                      result['coverage_failure_reasons'])

    def test_shortened_requested_session_cannot_pass(self):
        self.capture()
        self.route({'requested_duration_seconds': 600})
        self.assertFalse(pacing.analyze(self.root)['pacing_gate_passed'])

    def test_legacy_report_remains_analyzable_without_certifying_coverage(self):
        self.capture()
        path = self.data / 'streaming.json'
        report = json.loads(path.read_text())
        del report['route_started_unix_seconds']
        del report['route_finished_unix_seconds']
        path.write_text(json.dumps(report))
        result = pacing.analyze(self.root)
        self.assertGreater(result['average_fps'], 30)
        self.assertFalse(result['pacing_gate_passed'])
        self.assertIn('route start/end clock anchors are missing or invalid',
                      result['coverage_failure_reasons'])

    def test_invalid_route_metadata_cannot_certify_coverage(self):
        self.capture()
        original = json.loads((self.data / 'streaming.json').read_text())
        for key, values in [('actual_duration_seconds', [None, True, -1, 0, float('nan'), float('inf')]),
                            ('requested_duration_seconds', [None, True, -1, float('nan')]),
                            ('route_started_unix_seconds', [None, True, float('nan')]),
                            ('route_finished_unix_seconds', [None, True, 99, float('inf')]),
                            ('capture_enabled', [None, False, 1, 'true', [], {}]),
                            ('route_passed', [None, False, 1, 'true']),
                            ('legs', [None, 'passed', {'passed': True}, [], [{}], [{'passed': False}]])]:
            for value in values:
                with self.subTest(key=key, value=value):
                    self.route({**original, key: value})
                    self.assertFalse(pacing.analyze(self.root)['pacing_gate_passed'])

    def test_nonlist_legs_stay_analyzable_with_an_explicit_coverage_reason(self):
        self.capture()
        for value in [None, 'passed', {'passed': True}]:
            with self.subTest(legs=value):
                self.route({'legs': value})
                result = pacing.analyze(self.root)
                self.assertEqual(result['legs'], 0)
                self.assertGreater(result['average_fps'], 30)
                self.assertFalse(result['pacing_gate_passed'])
                self.assertIn('route leg results are missing or incomplete',
                              result['coverage_failure_reasons'])

    def test_missing_required_route_metadata_stays_analyzable_without_approval(self):
        self.capture()
        path = self.data / 'streaming.json'
        original = json.loads(path.read_text())
        for key in ['legs', 'capture_enabled']:
            with self.subTest(missing=key):
                report = original.copy()
                del report[key]
                path.write_text(json.dumps(report))
                result = pacing.analyze(self.root)
                self.assertGreater(result['average_fps'], 30)
                self.assertFalse(result['pacing_gate_passed'])
                self.assertTrue(result['coverage_failure_reasons'])

    def test_report_roots_must_be_json_objects(self):
        self.capture()
        route_path = self.data / 'streaming.json'
        capture_path = self.captures / '001.json'
        route_original = route_path.read_text()
        for value in [None, [], 'invalid', 1]:
            with self.subTest(route=value):
                route_path.write_text(json.dumps(value))
                with self.assertRaisesRegex(ValueError, 'route report must be a JSON object'):
                    pacing.analyze(self.root)
        route_path.write_text(route_original)
        for value in [None, [], 'invalid', 1]:
            with self.subTest(capture=value):
                capture_path.write_text(json.dumps(value))
                with self.assertRaisesRegex(ValueError, 'capture report must be a JSON object'):
                    pacing.analyze(self.root)

    def test_total_missing_time_has_one_fixed_budget(self):
        self.capture()
        self.capture('002', anchor=100.063)
        self.capture('003', anchor=100.126)
        self.route({'actual_duration_seconds': .159, 'route_finished_unix_seconds': 100.159})
        result = pacing.analyze(self.root)
        self.assertTrue(all(0 < gap['seconds'] < .05 for gap in result['capture_boundary_gaps']))
        self.assertAlmostEqual(result['uncaptured_route_seconds'], .06)
        self.assertFalse(result['pacing_gate_passed'])

    def test_fast_p99_cannot_hide_a_one_percent_low_below_thirty(self):
        frames = [16] * 99 + [40]
        duration = sum(frames) / 1000
        self.capture(frames=frames)
        self.route({'actual_duration_seconds': duration,
                    'route_finished_unix_seconds': 100 + duration})
        result = pacing.analyze(self.root)
        self.assertTrue(result['coverage_complete'])
        self.assertEqual(result['p99_frame_ms'], 16)
        self.assertEqual(result['frames_over_50_ms'], 0)
        self.assertEqual(result['one_percent_low_fps'], 25)
        self.assertFalse(result['pacing_gate_passed'])

    def test_small_overlaps_cannot_cancel_accumulated_missing_intervals(self):
        anchor = 100.0
        for index in range(121):
            self.capture(f'{index:03}', anchor=anchor)
            # Every overlap is within clock precision, and every gap is below
            # the per-boundary hitch threshold. Their sums cancel exactly.
            anchor += .033 + (.001 if index % 2 == 0 else -.001)
        duration = 121 * .033
        self.route({'actual_duration_seconds': duration,
                    'route_finished_unix_seconds': 100 + duration})
        result = pacing.analyze(self.root)
        self.assertAlmostEqual(result['capture_duration_discrepancy_seconds'], 0)
        self.assertTrue(all(-.002 < gap['seconds'] < .05
                            for gap in result['capture_boundary_gaps']))
        self.assertGreater(result['uncaptured_route_seconds'], .05)
        self.assertFalse(result['pacing_gate_passed'])

    def test_rotation_stall_cannot_hide_between_fast_captures(self):
        self.capture()
        self.capture('002', anchor=100.233)
        self.route({'actual_duration_seconds': .266, 'route_finished_unix_seconds': 100.266})
        result = pacing.analyze(self.root)
        self.assertEqual(result['frames_over_50_ms'], 0)
        self.assertAlmostEqual(result['capture_boundary_gaps'][0]['seconds'], .2)
        self.assertFalse(result['pacing_gate_passed'])

    def test_missing_clock_anchor_cannot_certify_coverage(self):
        for anchor in [None, True, float('nan')]:
            with self.subTest(anchor=anchor):
                self.capture(anchor=anchor)
                self.assertFalse(pacing.analyze(self.root)['pacing_gate_passed'])

    def test_unfocused_spike_is_retained(self):
        self.capture(frames=(16, 90), unfocused=1)
        result = pacing.analyze(self.root)
        self.assertEqual(result['frames_over_50_ms'], 1)
        self.assertFalse(result['pacing_gate_passed'])

    def test_incomplete_csv_rejected(self):
        self.capture()
        path = self.captures / '001-frames.csv'
        path.write_text('frame,elapsed_seconds,frame_ms\n0,0.016,16\n')
        with self.assertRaises(ValueError):
            pacing.analyze(self.root)

    def test_monitor_preserves_child_failure_and_writes_sample(self):
        output = self.root / 'hardware.jsonl'
        child = subprocess.run([sys.executable, str(ROOT / 'scripts/tools/hardware_monitor.py'),
                                '--output', str(output), '--', sys.executable, '-c',
                                'raise SystemExit(7)'], capture_output=True, text=True, timeout=5)
        self.assertEqual(child.returncode, 7, child.stderr)
        self.assertIn('game_pid', json.loads(output.read_text().splitlines()[0]))

    def test_blocked_sensor_is_discarded_without_stopping_other_samples(self):
        blocked = self.root / 'blocked'
        os.mkfifo(blocked)
        healthy = self.root / 'healthy'
        healthy.write_text('42000')
        sampler = monitor.SensorSampler([blocked, healthy], timeout=.05)
        self.addCleanup(sampler.close)
        started = time.monotonic()
        sampler.collect(budget=.02)
        self.assertLess(time.monotonic() - started, .5)
        deadline = time.monotonic() + 2
        values = {}
        while time.monotonic() < deadline:
            values = sampler.collect(budget=.03)
            if values[str(healthy)] is not None:
                break
            time.sleep(.02)
        self.assertEqual(values[str(healthy)], '42000')
        self.assertIn(str(blocked), sampler.unavailable)


if __name__ == '__main__':
    unittest.main()
