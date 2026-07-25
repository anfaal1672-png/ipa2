#!/usr/bin/env bash
#
# Boots the app in an iOS simulator and checks it is still alive a few seconds
# later — the cheapest possible guard against crash-on-launch bugs (a trapping
# dictionary literal shipped exactly that once).
#
# Runs twice: once with the device's default language, once forced to Japanese,
# because the Japanese path touches code the English path never evaluates.
#
# Usage: Tools/smoke_test.sh <path-to-CodeForge.app>
set -euo pipefail

APP_PATH="${1:?usage: smoke_test.sh <CodeForge.app>}"
BUNDLE_ID="com.codeforge.editor"
DEVICE_NAME="${SMOKE_DEVICE:-iPhone 16}"

echo "==> Booting simulator: $DEVICE_NAME"
DEVICE_ID=$(xcrun simctl list devices available -j \
  | python3 -c "
import json, sys
data = json.load(sys.stdin)['devices']
name = '$DEVICE_NAME'
fallback = None
for runtime, devices in data.items():
    if 'iOS' not in runtime:
        continue
    for device in devices:
        if device['name'] == name:
            print(device['udid']); raise SystemExit
        fallback = fallback or device['udid']
print(fallback or '')
")

if [ -z "$DEVICE_ID" ]; then
  echo "no iOS simulator available" >&2
  exit 1
fi

xcrun simctl boot "$DEVICE_ID" 2>/dev/null || true
xcrun simctl bootstatus "$DEVICE_ID" -b

echo "==> Installing $APP_PATH"
xcrun simctl install "$DEVICE_ID" "$APP_PATH"

run_once() {
  local label="$1"; shift
  echo "==> Launching ($label)"
  xcrun simctl terminate "$DEVICE_ID" "$BUNDLE_ID" 2>/dev/null || true
  rm -f ~/Library/Logs/DiagnosticReports/CodeForge*.ips 2>/dev/null || true

  local output
  output=$(xcrun simctl launch --console-pty "$DEVICE_ID" "$BUNDLE_ID" "$@" 2>&1 &
           sleep 8; echo)
  local pid
  pid=$(xcrun simctl spawn "$DEVICE_ID" launchctl list 2>/dev/null \
        | awk -v id="UIKitApplication:$BUNDLE_ID" '$3 ~ id { print $1 }' | head -1)

  if [ -n "${pid:-}" ] && [ "$pid" != "-" ] && [ "$pid" != "0" ]; then
    echo "    still running (pid $pid) ✓"
    xcrun simctl terminate "$DEVICE_ID" "$BUNDLE_ID" 2>/dev/null || true
    return 0
  fi

  echo "!!! app is not running after launch ($label)" >&2
  echo "--- launch output ---" >&2
  echo "$output" >&2
  echo "--- crash reports ---" >&2
  for report in ~/Library/Logs/DiagnosticReports/CodeForge*.ips; do
    [ -e "$report" ] || continue
    echo "### $report" >&2
    head -120 "$report" >&2
  done
  echo "--- recent device log ---" >&2
  xcrun simctl spawn "$DEVICE_ID" log show --last 60s --style compact \
    --predicate "process == \"CodeForge\"" 2>/dev/null | tail -80 >&2 || true
  return 1
}

status=0
run_once "system language" || status=1
run_once "Japanese" -AppleLanguages "(ja)" -AppleLocale ja_JP || status=1

xcrun simctl shutdown "$DEVICE_ID" 2>/dev/null || true

if [ "$status" -ne 0 ]; then
  echo "==> SMOKE TEST FAILED"
  exit 1
fi
echo "==> Smoke test passed"
