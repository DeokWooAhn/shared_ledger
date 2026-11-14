#!/usr/bin/env bash
# CI의 테스트 전용 시뮬레이터 앱을 로컬 Auth·Firestore와 검증한다.
set -euo pipefail
cd "$(dirname "$0")/../.."
: "${IOS_SIMULATOR_UDID:?테스트할 시뮬레이터 UDID가 필요합니다.}"
output=build/maestro/ios
mkdir -p "$output"

if [[ "${1:-}" == --flows ]]; then
  collect_before_emulator_shutdown() {
    result=$?
    trap - EXIT
    python3 .github/scripts/collect_ios_diagnostics.py --udid "$IOS_SIMULATOR_UDID" \
      --app-id com.ahn.SharedLedger --process Runner --output "$output/diagnostics" \
      --started "$output/diagnostics-started" || true
    exit "$result"
  }
  trap collect_before_emulator_shutdown EXIT
  # CLI를 두 번 띄우면 워밍업 드라이버 종료와 새 XCTest 세션이 겹칠 수 있다.
  bash scripts/maestro-smoke.sh --run ios "$IOS_SIMULATOR_UDID"
  exit
fi

rm -f "$output/diagnostics/summary.json"
touch "$output/diagnostics-started"
xcrun simctl spawn "$IOS_SIMULATOR_UDID" log stream --style compact \
  --predicate 'process == "Runner"' > "$output/app.log" 2>&1 &
log_pid=$!
cleanup() {
  result=$?
  trap - EXIT
  kill "$log_pid" 2>/dev/null || true
  if [[ ! -f "$output/diagnostics/summary.json" ]]; then
    python3 .github/scripts/collect_ios_diagnostics.py --udid "$IOS_SIMULATOR_UDID" \
      --app-id com.ahn.SharedLedger --process Runner --output "$output/diagnostics" \
      --started "$output/diagnostics-started" || true
  fi
  exit "$result"
}
trap cleanup EXIT
xcrun simctl install "$IOS_SIMULATOR_UDID" build/ios/iphonesimulator/Runner.app
firebase emulators:exec --config firebase.maestro.json \
  --project demo-shared-ledger --only auth,firestore \
  'bash .github/scripts/maestro-ios-smoke.sh --flows'
