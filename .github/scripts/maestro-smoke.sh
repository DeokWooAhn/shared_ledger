#!/usr/bin/env bash
# CI에서 미리 빌드한 테스트 APK를 설치하고, 실제 Firebase 규칙과 함께 smoke를 실행한다.
set -euo pipefail
cd "$(dirname "$0")/../.."
export ANDROID_SERIAL="${ANDROID_SERIAL:-emulator-5554}"
output=build/maestro/android
mkdir -p "$output"

if [[ "${1:-}" == --flows ]]; then
  # 이 앱은 Firebase 로그인이 끝나야 뜬다. 서버·가상 데이터를 준비하는 첫 Flow로 워밍업한다.
  maestro --device "$ANDROID_SERIAL" test .maestro/flows/01_navigation.yaml \
    -e APP_ID=com.ahn.sharedledger --test-output-dir "$output/warmup"
  bash scripts/maestro-smoke.sh --run android "$ANDROID_SERIAL"
  exit
fi

adb -s "$ANDROID_SERIAL" logcat -v threadtime > "$output/logcat.txt" 2>&1 &
logcat_pid=$!
trap 'kill "$logcat_pid" 2>/dev/null || true' EXIT
adb -s "$ANDROID_SERIAL" install -r build/app/outputs/flutter-apk/app-debug.apk
firebase emulators:exec --config firebase.maestro.json \
  --project demo-shared-ledger --only auth,firestore \
  'bash .github/scripts/maestro-smoke.sh --flows'
