# BlueSteer

Offline Bluetooth Low Energy terminal bridge for Claude Code, GitHub Copilot CLI and any other terminal agent.

A **Host** app on your Mac runs the agent session in a pseudo-terminal and advertises it over BLE. A **Remote** app on a phone or another computer, with no internet connection at all, attaches to that session as a real terminal: it sees the screen and types into it. Nothing goes through a relay server and nothing leaves the room.

Status: Phases 0–4 of `docs/PLAN.md` work end to end on macOS + Android + iOS: pair by QR code or by comparing a 6-digit code, open a login shell on the Mac from the phone, type into it, scroll back through its history, mirror a terminal you started yourself with `bluesteer run`, see when Claude is waiting for input or for permission, lose and regain the link without doing anything (a few seconds after the radio is back), and keep your sessions across a restart of the host app. Another Mac can be a remote too (`bluesteer connect`). In v1 the remote opens plain shells only; you run `claude` or `copilot` inside them. Packaging (Phase 5) is next.

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

On the phone tap **+**, then either scan the QR code or pick the Mac from the nearby list and confirm that both screens show the same 6-digit code. Tap the Mac: a terminal opens. "New terminal" starts another shell; exited ones disappear from the list. "Install Claude Code hooks…" in the Mac's menu lets the phone show when Claude is waiting for input or for permission.

Another Mac as the remote (same build, no app needed there):

```bash
.build/debug/bluesteer pair          # nearby Macs → compare the code; or: bluesteer pair 'bluesteer://pair?…'
.build/debug/bluesteer connect       # attach this terminal; Ctrl-] detaches
```

Tests: `swift test` in `apps/host` (including a 50-cycle in-process soak) and `packages/BlueSteerProtocol`, `dart test` in `packages/bluesteer_protocol_dart`, `flutter analyze` and `flutter test` in `apps/remote`, `tools/gen-proto.sh --check` for schema drift, `tools/interop-test.sh` for Swift↔Dart handshakes. `tools/soak/README.md` describes the long-run test with real phones and radio drops.

## Known limits (v1)

- The terminal's text is not exposed to screen readers (the `xterm` widget has no semantics); keys, buttons and status are.
- Nearby Macs show their name only after the phone has read it from each one (macOS advertises no local name next to the service UUID), which takes a second or two.
- The host's headless emulator (SwiftTerm) keeps at most 65,535 distinct colour/style combinations per session; beyond that new ones render with the default style in snapshots.
- Driving the iPhone from the Mac for tests needs UI automation enabled on the phone once per iOS update.

## Layout

- `protocol/` wire protocol spec, protobuf schema, test vectors
- `apps/host/` macOS host app and `bluesteer` command line tool (Swift)
- `apps/remote/` remote app (Flutter: iOS, Android, macOS; Windows later)
- `tools/` development tools: PTY recorder, bandwidth bench, BLE throughput bench, iPhone UI driver
- `docs/` plan, architecture overview, phase results, threat model

## License

Apache-2.0. See `LICENSE`.
