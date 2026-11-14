#!/usr/bin/env bash
# 테스트 전용 앱을 빌드·설치하고 로컬 Firebase와 함께 기본 Flow 세 개를 실행한다.
set -euo pipefail
cd "$(dirname "$0")/.."

run_only=false
if [[ "${1:-}" == "--run" ]]; then
  run_only=true
  shift
fi
platform="${1:-}"
device="${2:-}"
if [[ ! "$device" =~ ^[a-zA-Z0-9:_-]+$ ]] || [[ "$platform" != android && "$platform" != ios ]]; then
  echo "사용법: bash scripts/maestro-smoke.sh android <ADB 기기 ID> | ios <시뮬레이터 UDID>" >&2
  exit 1
fi
if [[ "$platform" == android ]]; then
  adb -s "$device" wait-for-device
  booted=false
  for attempt in {1..60}; do
    boot_state="$(adb -s "$device" shell getprop sys.boot_completed 2>/dev/null || true)"
    if [[ "${boot_state//$'\r'/}" == 1 ]]; then
      booted=true
      break
    fi
    sleep 2
  done
  if ! $booted; then
    echo "Android 부팅을 기다리다 시간이 지났습니다." >&2
    exit 1
  fi
  app_id=com.ahn.sharedledger
else
  app_id=com.ahn.SharedLedger
fi
result_dir="build/maestro/$platform"
mkdir -p "$result_dir"
# Firestore 에뮬레이터에 Java 21 이상이 필요하다. 별도 JAVA_HOME을 지정했다면 그대로 쓴다.
if [[ -z "${JAVA_HOME:-}" && -d "/Applications/Android Studio.app/Contents/jbr/Contents/Home" ]]; then
  export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
fi

if $run_only; then
  startup_timeout=30000
  if [[ "$platform" == ios ]]; then
    startup_timeout=60000
  fi
  maestro --device "$device" test .maestro --include-tags smoke \
    -e "APP_ID=$app_id" -e "STARTUP_TIMEOUT_MS=$startup_timeout" \
    --format JUNIT --output "$result_dir/results.xml" \
    --test-output-dir "$result_dir/artifacts" \
    --debug-output "$result_dir/debug" --flatten-debug-output
  exit
fi

if [[ "$platform" == android ]]; then
  # 스토어판을 지우거나 사용자 데이터에 손대지 않는다. 서명이 다른 앱도 install -r가 거부한다.
  if [[ "$(adb -s "$device" shell pm path "$app_id")" == package:* ]]; then
    if ! adb -s "$device" shell run-as "$app_id" true >/dev/null 2>&1; then
      echo "개발 빌드가 아닌 앱이 설치돼 있습니다. 사용자 확인 없이 교체하지 않습니다." >&2
      exit 1
    fi
  fi
  host=10.0.2.2
  if [[ "$device" != emulator-* ]]; then
    host=127.0.0.1
    adb -s "$device" reverse tcp:18080 tcp:18080
    adb -s "$device" reverse tcp:19099 tcp:19099
  fi
  fvm flutter build apk --debug --target testing/maestro_main.dart \
    --dart-define="MAESTRO_FIREBASE_HOST=$host"
  adb -s "$device" install -r build/app/outputs/flutter-apk/app-debug.apk
else
  # Maestro 2.1.0의 iOS 대상은 시뮬레이터다. 실기기를 지우거나 개발 앱으로 교체하지 않는다.
  xcrun simctl getenv "$device" SIMULATOR_UDID >/dev/null
  fvm flutter build ios --simulator --debug --target testing/maestro_main.dart
  xcrun simctl install "$device" build/ios/iphonesimulator/Runner.app
fi

firebase emulators:exec --config firebase.maestro.json \
  --project demo-shared-ledger --only auth,firestore \
  "bash scripts/maestro-smoke.sh --run $platform $device"
