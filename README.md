# BlueSteer

Offline Bluetooth Low Energy terminal bridge for Claude Code, GitHub Copilot CLI and any other terminal agent.

A **Host** app on your Mac runs the agent session in a pseudo-terminal and advertises it over BLE. A **Remote** app on a phone or another computer, with no internet connection at all, attaches to that session as a real terminal: it sees the screen and types into it. Nothing goes through a relay server and nothing leaves the room.

Status: Phase 2 of `docs/PLAN.md` works end to end on macOS + Android + iOS: pair by QR, open a login shell on the Mac from the phone, type into it, mirror a terminal you started yourself with `bluesteer run`. In v1 the remote opens plain shells only; you run `claude` or `copilot` inside them. Notifications, background sessions and packaging are still to come.

## Try it (developer build)

Host, on the Mac (Xcode 16+):

```bash
cd apps/host && swift build
.build/debug/BlueSteerHost          # menu-bar app; "Pair a remote…" shows the QR code
.build/debug/bluesteer run claude   # optional: mirror a session from your own terminal
```

Remote, on a phone (Flutter stable):

```bash
cd apps/remote && flutter run       # Android
flutter build ios --release         # iOS: set your team in ios/Runner.xcodeproj, then install the
                                    # built app with `xcrun devicectl device install app`; a debug
                                    # build only runs while `flutter run` is attached
```

On the phone tap **+**, scan the QR code, then tap the Mac: a terminal opens. "New terminal" starts another shell; exited ones disappear from the list. Tests: `swift test` in `apps/host` and `packages/BlueSteerProtocol`, `dart test` in `packages/bluesteer_protocol_dart`, `tools/gen-proto.sh --check` for schema drift, `tools/interop-test.sh` for Swift↔Dart handshakes.

## Layout

- `protocol/` wire protocol spec, protobuf schema, test vectors
- `apps/host/` macOS host app and `bluesteer` command line tool (Swift)
- `apps/remote/` remote app (Flutter: iOS, Android, macOS; Windows later)
- `tools/` development tools: PTY recorder, bandwidth bench, BLE throughput bench
- `docs/` plan, threat model, user documentation

## License

Apache-2.0. See `LICENSE`.
