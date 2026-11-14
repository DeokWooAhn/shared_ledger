"""CI 이미지의 iPhone 구성이 바뀌어도 실행할 시뮬레이터를 고르는지 확인한다."""

import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path


class IosSimulatorTest(unittest.TestCase):
    def select(self, devices):
        script = Path(__file__).with_name("ios-simulator-udid.sh").resolve()
        with tempfile.TemporaryDirectory() as directory:
            tools = Path(directory)
            fixture = tools / "devices.json"
            fixture.write_text(json.dumps({"devices": devices}), encoding="utf-8")
            xcrun = tools / "xcrun"
            xcrun.write_text('#!/bin/sh\ncat "$SIMULATOR_FIXTURE"\n', encoding="utf-8")
            xcrun.chmod(0o755)
            return subprocess.check_output(
                ["bash", str(script), "iPhone 17 Pro"],
                env={**os.environ, "PATH": f"{tools}{os.pathsep}{os.environ['PATH']}",
                     "SIMULATOR_FIXTURE": str(fixture)},
                text=True,
            ).strip()

    def test_preferred_phone_uses_newest_available_runtime(self):
        """원하는 기기가 여러 런타임에 있으면 최신 것을 고른다."""
        self.assertEqual(self.select({
            "com.apple.CoreSimulator.SimRuntime.iOS-26-0": [{"name": "iPhone 17 Pro", "udid": "older"}],
            "com.apple.CoreSimulator.SimRuntime.iOS-26-5": [{"name": "iPhone 17 Pro", "udid": "newer"}],
        }), "newer")

    def test_missing_preferred_phone_falls_back_to_newest_iphone(self):
        """새 CI 이미지에 기기 이름이 바뀌면 최신 iPhone으로 실행한다."""
        self.assertEqual(self.select({
            "com.apple.CoreSimulator.SimRuntime.iOS-26-0": [{"name": "iPhone 16", "udid": "older"}],
            "com.apple.CoreSimulator.SimRuntime.iOS-27-0": [
                {"name": "iPad Pro", "udid": "tablet"}, {"name": "iPhone 18 Pro", "udid": "newer"}],
        }), "newer")

    def test_no_iphone_returns_empty(self):
        """iPhone이 없으면 워크플로가 명확하게 실패할 수 있게 빈 값을 돌려준다."""
        self.assertEqual(self.select({
            "com.apple.CoreSimulator.SimRuntime.iOS-27-0": [{"name": "iPad Pro", "udid": "tablet"}],
        }), "")


if __name__ == "__main__":
    unittest.main()
