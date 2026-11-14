"""앱 시작 실패에도 기기 상태·통합 로그·새 크래시 보고서를 남긴다."""

import argparse
import json
import shutil
import subprocess
import time
from pathlib import Path


def capture(command, output, timeout=20):
    try:
        result = subprocess.run(command, capture_output=True, timeout=timeout, check=False)
        stdout, stderr, code = result.stdout, result.stderr, result.returncode
    except subprocess.TimeoutExpired as error:
        stdout, stderr, code = error.stdout or b"", error.stderr or b"", 124
    except OSError as error:
        stdout, stderr, code = b"", str(error).encode(), 127
    output.write_bytes(stdout)
    output.with_suffix(output.suffix + ".stderr").write_bytes(stderr)
    return {"command": command, "exit_code": code, "file": output.name}


def copy_reports(sources, destination, since, process, errors=None):
    destination.mkdir(parents=True, exist_ok=True)
    prefixes = (process, "maestro-driver", "xctest", "JetsamEvent", "SpringBoard", "Simulator")
    copied = []
    for index, source in enumerate(sources):
        if not source.is_dir():
            continue
        for path in source.rglob("*"):
            try:
                if path.suffix not in (".ips", ".crash") or not path.name.startswith(prefixes):
                    continue
                if path.stat().st_mtime < since:
                    continue
                target = destination / f"{index}-{path.name}"
                shutil.copy2(path, target)
                copied.append(target.name)
            except OSError as error:
                if errors is not None:
                    errors.append({"file": path.name, "error": str(error)})
                continue
    return copied


def collect(udid, app_id, process, output, started=None):
    output.mkdir(parents=True, exist_ok=True)
    since = started.stat().st_mtime if started and started.exists() else time.time() - 3600
    predicate = (
        f'process == "{process}" OR process CONTAINS "maestro-driver" OR '
        f'((process == "SpringBoard" OR process == "runningboardd") AND '
        f'eventMessage CONTAINS "{app_id}")'
    )
    commands = [
        ("toolchain.txt", ["xcodebuild", "-version"]),
        ("devices.json", ["xcrun", "simctl", "list", "devices", "-j"]),
        ("processes.txt", ["xcrun", "simctl", "spawn", udid, "launchctl", "list"]),
        ("screenshot-command.txt", ["xcrun", "simctl", "io", udid, "screenshot", str(output / "screen.png")]),
        ("system.log", ["xcrun", "simctl", "spawn", udid, "log", "show", "--style", "compact",
                        "--last", "15m", "--info", "--debug", "--predicate", predicate]),
    ]
    results = [capture(command, output / name) for name, command in commands]
    home = Path.home()
    sources = [home / "Library/Logs/DiagnosticReports",
               home / f"Library/Developer/CoreSimulator/Devices/{udid}/data/Library/Logs/CrashReporter"]
    errors = []
    reports = copy_reports(sources, output / "crash-reports", since, process, errors)
    summary = {"udid": udid, "app_id": app_id, "commands": results,
               "crash_reports": reports, "crash_report_errors": errors}
    (output / "summary.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n")
    return summary


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--udid", required=True)
    parser.add_argument("--app-id", required=True)
    parser.add_argument("--process", required=True)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--started", type=Path)
    args = parser.parse_args()
    result = collect(args.udid, args.app_id, args.process, args.output, args.started)
    print(f"iOS 진단 수집: 명령 {len(result['commands'])}개, 크래시 보고서 {len(result['crash_reports'])}개")
