"""문서 전용 변경은 건너뛰고 앱 삭제·이름 변경도 감지하는지 확인한다."""

import os
import subprocess
import tempfile
import unittest
from pathlib import Path

from maestro_changes import changed_paths, needs_smoke


class MaestroChangesTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.previous = Path.cwd()
        os.chdir(self.temporary.name)
        self.addCleanup(os.chdir, self.previous)
        self.git("init", "-q")
        self.git("config", "user.name", "CI 테스트")
        self.git("config", "user.email", "ci@example.test")
        self.git("config", "commit.gpgsign", "false")
        self.put("lib/feature/sample/sample_screen.dart", "기존 화면")
        self.put("README.md", "기존 문서")
        self.commit()
        self.base = self.git("rev-parse", "HEAD")

    def git(self, *args):
        return subprocess.check_output(["git", *args], stderr=subprocess.STDOUT).decode().strip()

    def put(self, name, text):
        path = Path(name)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")

    def commit(self):
        self.git("add", ".")
        self.git("commit", "-qm", "테스트 변경")

    def decision(self):
        self.commit()
        return needs_smoke(changed_paths(self.base, "HEAD"))

    def test_documents_and_server_only_skip_smoke(self):
        """문서·디자인·서버·단위 테스트만 바꾸면 기기 테스트를 건너뛴다."""
        for path in ("README.md", "docs/plan.md", "design/app.pen", "functions/index.ts", "test/widget_test.dart"):
            self.put(path, "설명 변경")
        self.assertFalse(self.decision())

    def test_ui_dependency_changes_run_smoke(self):
        """화면뿐 아니라 계산 규칙과 의존성 변경도 smoke를 실행한다."""
        self.put("lib/domain/budget/calculator.dart", "계산 규칙 변경")
        self.put("pubspec.lock", "의존성 변경")
        self.assertTrue(self.decision())

    def test_deleted_screen_runs_smoke(self):
        """화면 삭제도 실행 조건에 들어간다."""
        Path("lib/feature/sample/sample_screen.dart").unlink()
        self.assertTrue(self.decision())

    def test_screen_renamed_outside_app_runs_smoke(self):
        """앱 파일을 문서 경로로 옮겨도 원래 화면 삭제를 감지한다."""
        Path("docs").mkdir()
        self.git("mv", "lib/feature/sample/sample_screen.dart", "docs/old_screen.md")
        self.assertTrue(self.decision())

    def test_test_infrastructure_runs_smoke(self):
        """Flow와 CI 환경 변경은 새 기기 실행으로 확인한다."""
        self.put(".maestro/flows/01_navigation.yaml", "Flow 변경")
        self.put("firebase.maestro.json", "에뮬레이터 설정 변경")
        self.assertTrue(self.decision())

    def test_paths_with_spaces_and_newlines_are_not_split(self):
        """공백·줄바꿈이 있는 경로도 Git의 NUL 구분을 그대로 읽는다."""
        path = "assets/화면 자료\n테스트.txt"
        self.put(path, "가상 리소스")
        self.commit()
        self.assertIn(path, changed_paths(self.base, "HEAD"))
        self.assertTrue(needs_smoke(changed_paths(self.base, "HEAD")))


if __name__ == "__main__":
    unittest.main()
