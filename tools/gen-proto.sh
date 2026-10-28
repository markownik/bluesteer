#!/usr/bin/env bash
# Generates Swift and Dart code from protocol/bluesteer.proto.
# Requires: protoc, protoc-gen-swift (brew install swift-protobuf), protoc-gen-dart (dart pub global activate protoc_plugin).
# `--check` fails if the generated files are out of date (used by CI).
set -euo pipefail
cd "$(dirname "$0")/.."

SWIFT_OUT=packages/BlueSteerProtocol/Sources/BlueSteerProtocol/Generated
DART_OUT=packages/bluesteer_protocol_dart/lib/src/generated
mkdir -p "$SWIFT_OUT" "$DART_OUT"

if [[ "${1:-}" == "--check" ]]; then
  tmp=$(mktemp -d)
  protoc -I protocol --swift_out="$tmp" --dart_out="$tmp" protocol/bluesteer.proto
  diff "$tmp/bluesteer.pb.swift" "$SWIFT_OUT/bluesteer.pb.swift"
  for f in "$tmp"/*.dart; do diff "$f" "$DART_OUT/$(basename "$f")"; done
  echo "generated code is current"
  exit 0
fi

protoc -I protocol --swift_out="$SWIFT_OUT" --dart_out="$DART_OUT" protocol/bluesteer.proto
echo "generated into $SWIFT_OUT and $DART_OUT"
