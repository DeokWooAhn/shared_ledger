"""낮은 부하에서 안정화 스크립트가 오류나 불필요한 대기 없이 끝나는지 확인한다."""

import os
import subprocess
import tempfile
import unittest
from pathlib import Path


class EmulatorSettleTest(unittest.TestCase):
    def test_idle_emulator_finishes_without_warning(self):
        """CI의 GNU awk에서도 낮은 부하를 정상으로 판별한다."""
        script = Path(__file__).with_name("emulator-settle.sh").resolve()
        with tempfile.TemporaryDirectory() as directory:
            tools = Path(directory)
            adb = tools / "adb"
            adb.write_text(
                '#!/bin/sh\nif [ "$*" = "shell cat /proc/loadavg" ]; then echo "0.10 0.20 0.30 1/10 100"; fi\n',
                encoding="utf-8",
            )
            adb.chmod(0o755)
            timeout_stub = tools / "timeout"
            timeout_stub.write_text('#!/bin/sh\nshift\nexec "$@"\n', encoding="utf-8")
            timeout_stub.chmod(0o755)
            result = subprocess.run(
                ["bash", str(script), "0"],
                env={**os.environ, "PATH": f"{tools}{os.pathsep}{os.environ['PATH']}"},
                capture_output=True,
                text=True,
                check=True,
                timeout=10,
            )
            self.assertEqual(result.stderr, "")
            self.assertIn("에뮬레이터 부하 안정: 0.10", result.stdout)
            self.assertNotIn("::warning::", result.stdout)


if __name__ == "__main__":
    unittest.main()
