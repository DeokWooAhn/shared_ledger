#!/usr/bin/env bash
# CI의 테스트 전용 시뮬레이터 앱을 로컬 Auth·Firestore와 검증한다.
set -euo pipefail
cd "$(dirname "$0")/../.."
: "${IOS_SIMULATOR_UDID:?테스트할 시뮬레이터 UDID가 필요합니다.}"
output=build/maestro/ios
mkdir -p "$output"

if [[ "${1:-}" == --flows ]]; then
  maestro --device "$IOS_SIMULATOR_UDID" test .maestro/flows/01_navigation.yaml \
    -e APP_ID=com.ahn.SharedLedger --test-output-dir "$output/warmup"
  bash scripts/maestro-smoke.sh --run ios "$IOS_SIMULATOR_UDID"
  exit
fi

xcrun simctl spawn "$IOS_SIMULATOR_UDID" log stream --style compact \
  --predicate 'process == "Runner"' > "$output/app.log" 2>&1 &
log_pid=$!
trap 'kill "$log_pid" 2>/dev/null || true' EXIT
xcrun simctl install "$IOS_SIMULATOR_UDID" build/ios/iphonesimulator/Runner.app
firebase emulators:exec --config firebase.maestro.json \
  --project demo-shared-ledger --only auth,firestore \
  'bash .github/scripts/maestro-ios-smoke.sh --flows'
