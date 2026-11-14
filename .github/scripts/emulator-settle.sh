#!/usr/bin/env bash
# 부팅 표시 이후에도 남아 있는 패키지 설치·dexopt 작업이 테스트를 막지 않게 기다린다.
set -euo pipefail
max_wait="${1:-120}"
adb wait-for-device
for attempt in {1..60}; do
  if adb shell pm path android >/dev/null 2>&1; then
    break
  fi
  sleep 2
done
adb shell pm path android >/dev/null
if ! timeout 600 adb shell cmd package bg-dexopt-job; then
  echo "::warning::밀린 dexopt 작업을 모두 끝내지 못했습니다."
fi
start=$(date +%s)
while true; do
  emulator_load_average=$(adb shell cat /proc/loadavg | cut -d' ' -f1)
  elapsed=$(( $(date +%s) - start ))
  if awk -v emulator_load_average="$emulator_load_average" 'BEGIN { exit !(emulator_load_average < 2.0) }'; then
    echo "에뮬레이터 부하 안정: $emulator_load_average"
    break
  fi
  if [[ "$elapsed" -ge "$max_wait" ]]; then
    echo "::warning::에뮬레이터 부하가 $emulator_load_average 상태입니다. 테스트를 계속합니다."
    break
  fi
  sleep 10
done
