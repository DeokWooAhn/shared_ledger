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
