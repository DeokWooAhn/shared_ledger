"""기기가 응답하지 않아도 진단과 원래 실패를 잃지 않는지 확인한다."""

import subprocess
import os
import shutil
import tempfile
import time
import unittest
from pathlib import Path
from unittest.mock import patch

from collect_ios_diagnostics import capture, collect, copy_reports


class IosDiagnosticsTest(unittest.TestCase):
    def test_ios_suite_uses_one_driver_session_and_preserves_result(self):
        for status in (0, 7):
            with self.subTest(status=status), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                source = Path(__file__).resolve().parents[2]
                for relative in ('.github/scripts/maestro-ios-smoke.sh', 'scripts/maestro-smoke.sh'):
                    target = root / relative
                    target.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(source / relative, target)
                binaries = root / 'bin'
                binaries.mkdir()
                calls = root / 'calls.txt'
                maestro = binaries / 'maestro'
                maestro.write_text('#!/bin/sh\nprintf "%s\\n" "$*" >> "$MAESTRO_CALLS_FILE"\n'
                                   f'exit {status}\n')
                maestro.chmod(0o755)
                python = binaries / 'python3'
                python.write_text('#!/bin/sh\nexit 13\n')
                python.chmod(0o755)
                result = subprocess.run(
                    ['bash', str(root / '.github/scripts/maestro-ios-smoke.sh'), '--flows'],
                    cwd=root, capture_output=True, timeout=5,
                    env={**os.environ, 'PATH': f'{binaries}{os.pathsep}{os.environ["PATH"]}',
                         'HOME': str(root), 'IOS_SIMULATOR_UDID': 'test-device',
                         'MAESTRO_CALLS_FILE': str(calls)},
                )
                self.assertEqual(result.returncode, status, result.stderr)
                arguments = calls.read_text().splitlines()
                self.assertEqual(len(arguments), 1)
                self.assertIn('STARTUP_TIMEOUT_MS=60000', arguments[0])
                self.assertIn('SERVER_VERIFY_TIMEOUT_MS=120000', arguments[0])

    def test_failed_diagnostics_cannot_hide_maestro_failure(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            scripts = root / '.github/scripts'
            scripts.mkdir(parents=True)
            wrapper = scripts / 'maestro-ios-smoke.sh'
            shutil.copy2(Path(__file__).with_name('maestro-ios-smoke.sh'), wrapper)
            binaries = root / 'bin'
            binaries.mkdir()
            for name, code in [('xcrun', 0), ('maestro', 7), ('firebase', 7), ('python3', 13)]:
                executable = binaries / name
                executable.write_text(f'#!/bin/sh\nexit {code}\n')
                executable.chmod(0o755)
            result = subprocess.run(['bash', str(wrapper)], cwd=root, capture_output=True, timeout=5,
                                    env={**os.environ, 'PATH': f'{binaries}{os.pathsep}{os.environ["PATH"]}',
                                         'HOME': str(root), 'UDID': 'test-device', 'IOS_SIMULATOR_UDID': 'test-device',
                                         'APP_ID': 'test.app', 'APP_PATH': 'Test.app', 'MAESTRO_TAGS': 'smoke'})
            self.assertEqual(result.returncode, 7, result.stderr)

    def test_timeout_keeps_partial_output(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "system.log"
            with patch("collect_ios_diagnostics.subprocess.run", side_effect=subprocess.TimeoutExpired(
                ["xcrun"], 20, output=b"partial diagnostic", stderr=b"not responding"
            )):
                result = capture(["xcrun"], output)
            self.assertEqual(result["exit_code"], 124)
            self.assertEqual(output.read_bytes(), b"partial diagnostic")
            self.assertEqual(output.with_suffix(".log.stderr").read_bytes(), b"not responding")

    def test_missing_tool_still_writes_summary(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "diagnostics"
            with patch("collect_ios_diagnostics.subprocess.run", side_effect=FileNotFoundError("xcrun")), \
                    patch("collect_ios_diagnostics.copy_reports", return_value=[]):
                result = collect("test-device", "test.app", "TestApp", output)
            self.assertTrue((output / "summary.json").exists())
            self.assertTrue(all(command["exit_code"] == 127 for command in result["commands"]))

    def test_only_new_related_crashes_are_copied(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "TestApp-new.ips").write_text("new")
            (root / "OtherApp-new.ips").write_text("unrelated")
            since = time.time() + 1
            self.assertEqual(copy_reports([root], root / "before", since, "TestApp"), [])
            copied = copy_reports([root], root / "after", since - 5, "TestApp")
            self.assertEqual(copied, ["0-TestApp-new.ips"])


if __name__ == "__main__":
    unittest.main()
