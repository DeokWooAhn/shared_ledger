"""화면과 그 동작에 영향을 주는 변경이 있을 때만 Maestro를 실행한다."""

import os
import subprocess
from pathlib import Path


APP_PREFIXES = ("lib/", "android/", "ios/", "assets/", ".maestro/", ".github/scripts/")
APP_FILES = {
    "pubspec.yaml",
    "pubspec.lock",
    ".fvmrc",
    "firestore.rules",
    "firestore.indexes.json",
    "firebase.maestro.json",
    "testing/maestro_main.dart",
    "scripts/maestro-smoke.sh",
    ".github/workflows/ci.yml",
}


def changed_paths(base, head):
    # 이름을 바꿔 앱 경로 밖으로 옮긴 경우에도, 원래 앱 파일의 삭제를 놓치지 않는다.
    result = subprocess.check_output(
        ["git", "diff", "--no-renames", "--name-only", "-z", f"{base}...{head}"]
    )
    return [os.fsdecode(path) for path in result.split(b"\0") if path]


def needs_smoke(paths):
    return any(path.startswith(APP_PREFIXES) or path in APP_FILES for path in paths)


def main():
    event = os.environ["EVENT_NAME"]
    base = os.environ.get("BASE_SHA", "")
    head = os.environ["HEAD_SHA"]
    if event == "workflow_dispatch" or not base or set(base) == {"0"}:
        run = True
        print("수동 실행 또는 최초 푸시라 smoke를 실행합니다.")
    else:
        paths = changed_paths(base, head)
        run = needs_smoke(paths)
        print("변경 경로:", repr(paths))
    decision = str(run).lower()
    print(f"Maestro 실행: {decision}")
    with Path(os.environ["GITHUB_OUTPUT"]).open("a", encoding="utf-8") as output:
        output.write(f"run={decision}\n")


if __name__ == "__main__":
    main()
