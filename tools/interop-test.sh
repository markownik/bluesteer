#!/usr/bin/env bash
# Cross-language SecureChannel check: Swift host probe <-> Dart remote probe over loopback TCP.
set -euo pipefail
cd "$(dirname "$0")/.."
export PATH="$PATH:$HOME/.pub-cache/bin"
PORT=${PORT:-47999}
PSK=$(python3 -c "import os;print(os.urandom(32).hex())")
swift build --package-path tools --product channel-probe >/dev/null
LOG=$(mktemp)
tools/.build/debug/channel-probe "$PORT" "$PSK" > "$LOG" 2>&1 &
HOST_PID=$!
trap 'kill $HOST_PID 2>/dev/null || true' EXIT
for _ in $(seq 1 100); do grep -q listening "$LOG" && break; sleep 0.1; done
(cd packages/bluesteer_protocol_dart && dart pub get >/dev/null && dart run tool/probe_remote.dart "$PORT" "$PSK")
wait $HOST_PID
cat "$LOG"
