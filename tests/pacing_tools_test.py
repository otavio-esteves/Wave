"""Integrity checks for exported pacing evidence and the telemetry wrapper."""
import csv
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('pacing', ROOT / 'scripts/tools/analyze_pacing.py')
pacing = importlib.util.module_from_spec(spec)
spec.loader.exec_module(pacing)


class PacingEvidenceTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.data = self.root / 'data/godot/app_userdata/Wave'
        self.captures = self.data / 'performance'
        self.captures.mkdir(parents=True)
        (self.data / 'streaming.json').write_text(json.dumps({'route_passed': True, 'legs': [{}]}))

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
        self.assertTrue(pacing.analyze(self.root)['pacing_gate_passed'])

    def test_rotation_stall_cannot_hide_between_fast_captures(self):
        self.capture()
        self.capture('002', anchor=100.233)
        result = pacing.analyze(self.root)
        self.assertEqual(result['frames_over_50_ms'], 0)
        self.assertAlmostEqual(result['capture_boundary_gaps'][0]['seconds'], .2)
        self.assertFalse(result['pacing_gate_passed'])

    def test_missing_clock_anchor_cannot_certify_coverage(self):
        self.capture(anchor=None)
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
                                'raise SystemExit(7)'], capture_output=True, text=True)
        self.assertEqual(child.returncode, 7, child.stderr)
        self.assertIn('game_pid', json.loads(output.read_text().splitlines()[0]))


if __name__ == '__main__':
    unittest.main()
