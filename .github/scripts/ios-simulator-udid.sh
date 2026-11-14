#!/usr/bin/env bash
# 지정한 iPhone을 우선 쓰고, 없으면 최신 iOS 런타임의 iPhone을 고른다.
set -euo pipefail
xcrun simctl list devices available -j | jq -r --arg name "${1:-iPhone 17 Pro}" '
  [.devices | to_entries[]
   | select(.key | test("SimRuntime\\.iOS-"))
   | {ver: (.key | capture("iOS-(?<v>[0-9-]+)$").v | split("-") | map(tonumber)),
      dev: (.value[] | select(.name | startswith("iPhone")))}]
  | sort_by(.ver)
  | ((map(select(.dev.name == $name)) | last) // last)
  | .dev.udid // empty'
