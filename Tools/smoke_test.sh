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
DEVICE_NAME="${SMOKE_DEVICE:-iPhone 17}"

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

  # Plain `simctl launch` returns as soon as the app is spawned. Capturing a
  # `--console-pty` launch instead would block until the app exits, which for a
  # healthy app is never.
  if ! xcrun simctl launch "$DEVICE_ID" "$BUNDLE_ID" "$@" > launch-output.txt 2>&1; then
    echo "!!! simctl launch failed ($label)" >&2
    cat launch-output.txt >&2
    return 1
  fi
  cat launch-output.txt

  sleep 8

  local pid
  pid=$(xcrun simctl spawn "$DEVICE_ID" launchctl list 2>/dev/null \
        | awk -v id="UIKitApplication:$BUNDLE_ID" '$3 ~ id { print $1 }' | head -1)

  if [ -n "${pid:-}" ] && [ "$pid" != "-" ] && [ "$pid" != "0" ]; then
    echo "    still running (pid $pid) ✓"
    xcrun simctl terminate "$DEVICE_ID" "$BUNDLE_ID" 2>/dev/null || true
    return 0
  fi

  echo "!!! app is not running after launch ($label)" >&2
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

# The launch checks only prove the app opens. This runs the in-app self test,
# which exercises the loopback server, the bundled runtimes and the scanner.
echo "==> Self test"
xcrun simctl terminate "$DEVICE_ID" "$BUNDLE_ID" 2>/dev/null || true
if xcrun simctl launch "$DEVICE_ID" "$BUNDLE_ID" --selftest > selftest-launch.txt 2>&1; then
  sleep 12
  LOG=$(xcrun simctl spawn "$DEVICE_ID" log show --last 60s --style compact \
        --predicate 'process == "CodeForge"' 2>/dev/null | grep SELFTEST || true)
  echo "$LOG"
  if echo "$LOG" | grep -q "SELFTEST RESULT pass"; then
    echo "    self test passed ✓"
  else
    echo "!!! self test did not pass" >&2
    status=1
  fi
else
  echo "!!! could not launch for the self test" >&2
  cat selftest-launch.txt >&2
  status=1
fi
xcrun simctl terminate "$DEVICE_ID" "$BUNDLE_ID" 2>/dev/null || true

xcrun simctl shutdown "$DEVICE_ID" 2>/dev/null || true

if [ "$status" -ne 0 ]; then
  echo "==> SMOKE TEST FAILED"
  exit 1
fi
echo "==> Smoke test passed"
