#!/usr/bin/env bash
# Cross-language SecureChannel check: Swift host probe <-> Dart remote probe over loopback TCP.
set -euo pipefail
cd "$(dirname "$0")/.."
export PATH="$PATH:$HOME/.pub-cache/bin"
PORT=${PORT:-47999}
swift build --package-path tools --product channel-probe >/dev/null
(cd packages/bluesteer_protocol_dart && dart pub get >/dev/null)

run_mode() {  # $1 = psk hex or "code"
  local LOG; LOG=$(mktemp)
  tools/.build/debug/channel-probe "$PORT" "$1" > "$LOG" 2>&1 &
  local HOST_PID=$!
  for _ in $(seq 1 100); do grep -q listening "$LOG" && break; sleep 0.1; done
  local REMOTE_OUT
  REMOTE_OUT=$(cd packages/bluesteer_protocol_dart && dart run tool/probe_remote.dart "$PORT" "$1")
  wait $HOST_PID
  echo "$REMOTE_OUT"; cat "$LOG"
  if [ "$1" = code ]; then
    local a b
    a=$(echo "$REMOTE_OUT" | sed -n 's/^pairing code //p'); b=$(sed -n 's/^pairing code //p' "$LOG")
    [ -n "$a" ] && [ "$a" = "$b" ] || { echo "pairing codes differ: remote=$a host=$b"; exit 1; }
    echo "pairing codes match ($a)"
  fi
}

run_mode "$(python3 -c "import os;print(os.urandom(32).hex())")"
run_mode code
