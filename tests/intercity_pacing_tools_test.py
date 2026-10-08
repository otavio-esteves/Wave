"""Check that the intercity diagnostic cannot silently accept corrupt evidence."""
import csv
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('intercity_pacing', ROOT / 'scripts/tools/analyze_intercity_pacing.py')
pacing = importlib.util.module_from_spec(spec)
spec.loader.exec_module(pacing)


class IntercityPacingTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.run = self.root / '1-on'
        self.data = self.run / 'data/godot/app_userdata/Wave'
        self.data.mkdir(parents=True)
        frames = [16, 60]
        self.report = {'capture_enabled': True, 'gpu': 'fixture', 'window_size': '(854, 480)',
                       'renderer': 'gl_compatibility', 'graphics': {}, 'fps_limit': 0, 'vsync_mode': 0,
                       'legs': [{'leg': 'outward', 'frames': 2, 'capture_started_unix_seconds': 100,
                                 'unfocused_frames': 0, 'average_fps': 2000 / 76,
                                 'p99_frame_ms': 60, 'slowest_frame_ms': 60,
                                 'one_percent_low_fps': 1000 / 60, 'frames_over_50_ms': 1}]}
        self.report['legs'].append({**self.report['legs'][0], 'leg': 'return'})
        self.report['hlod'] = {'detail_enter_m': 180, 'events': [
            {'process_frame': 9, 'cell': 'vale-0'}, {'process_frame': 99, 'cell': 'vale-0'}]}
        self.write_report()
        route = {'failures': 0, 'outward': {'arrived': True, 'grounded': True},
                 'return': {'arrived': True, 'grounded': True},
                 'streaming': {'events': [{'process_frame': 11, 'phase': 'attach'},
                                          {'process_frame': 99, 'phase': 'release_cpu'}]}}
        (self.data / 'intercity.json').write_text(json.dumps(route))
        (self.run / 'hardware.jsonl').write_text(json.dumps({'unix_seconds': 100}) + '\n')
        with (self.data / 'pacing-frames.csv').open('w') as output:
            writer = csv.writer(output)
            writer.writerow(['leg', 'process_frame', 'frame_ms', 'target_z', 'cell', 'focused'])
            for index, ms in enumerate(frames):
                writer.writerow(['outward', index + 10, ms, -10, 'fixture', 'true'])
            for index, ms in enumerate(frames):
                writer.writerow(['return', index + 12, ms, -10, 'fixture', 'true'])

    def write_report(self):
        (self.data / 'pacing.json').write_text(json.dumps(self.report))

    def test_spike_retained_with_only_adjacent_events(self):
        result = pacing.analyze(self.root)['runs'][0]
        spike = result['legs'][0]['spikes'][0]
        self.assertEqual(spike['nearby_streaming_events'], [{'process_frame': 11, 'phase': 'attach'}])
        self.assertEqual(spike['nearby_hlod_events'], [{'process_frame': 9, 'cell': 'vale-0'}])
        self.assertAlmostEqual(spike['telemetry_age_seconds'], .076)

    def test_corrupt_summary_rejected(self):
        self.report['legs'][0]['slowest_frame_ms'] = 16
        self.write_report()
        with self.assertRaises(ValueError):
            pacing.analyze(self.root)

    def test_missing_frame_rejected(self):
        path = self.data / 'pacing-frames.csv'
        path.write_text('\n'.join(path.read_text().splitlines()[:2]) + '\n')
        with self.assertRaises(ValueError):
            pacing.analyze(self.root)

    def test_mixed_settings_rejected(self):
        import shutil
        second = self.root / '1-off'
        shutil.copytree(self.run, second)
        path = second / 'data/godot/app_userdata/Wave/pacing.json'
        self.report['gpu'] = 'other'
        path.write_text(json.dumps(self.report))
        with self.assertRaises(ValueError):
            pacing.analyze(self.root)


if __name__ == '__main__':
    unittest.main()
