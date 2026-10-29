# BlueSteer

Offline Bluetooth Low Energy terminal bridge for Claude Code, GitHub Copilot CLI and any other terminal agent.

A **Host** app on your Mac runs the agent session in a pseudo-terminal and advertises it over BLE. A **Remote** app on a phone or another computer, with no internet connection at all, attaches to that session as a real terminal: it sees the screen and types into it. Nothing goes through a relay server and nothing leaves the room.

Status: Phases 0–4 of `docs/PLAN.md` work end to end on macOS + Android + iOS: pair by QR code or by comparing a 6-digit code, open a login shell on the Mac from the phone, type into it, scroll back through its history, mirror a terminal you started yourself with `bluesteer run`, see when Claude is waiting for input or for permission, lose and regain the link without doing anything (a few seconds after the radio is back), and keep your sessions across a restart of the host app. Another Mac can be a remote too (`bluesteer connect`). In v1 the remote opens plain shells only; you run `claude` or `copilot` inside them. Packaging and the store submissions (Phase 5) are in progress.

## Get it

- **BlueSteer Host** (macOS, menu bar): a signed and notarized build will be sold as a one-time purchase with free updates (link to follow); everything needed to build it yourself is below and in this repository.
- **BlueSteer Remote** (iPhone, Android): free on the App Store and Google Play once published; buildable from this repository too.
- **Another Mac as the remote:** the `bluesteer` command line tool that ships inside the host app.

## Build from source

Prerequisites:

- macOS 14 or newer with Xcode 16 or newer (Swift 5.9+). The host is a Swift package; no Xcode project is needed.
- Flutter stable (3.47 is what the apps are built with; `flutter doctor` must be happy for Android and/or iOS).
- A phone with Bluetooth Low Energy: Android 12+ or iOS 16+.
- No protobuf compiler: the generated code is committed. Only after editing `protocol/bluesteer.proto` you need `protoc`, `brew install swift-protobuf` and `dart pub global activate protoc_plugin`, then `tools/gen-proto.sh`.

### Host (the Mac you want to steer)

```bash
git clone https://github.com/<owner>/bluesteer && cd bluesteer
tools/bundle-app.sh              # builds build/BlueSteer.app (release, ad-hoc signed)
open build/BlueSteer.app         # menu-bar icon; macOS asks for Bluetooth once
```

An ad-hoc signed app runs on the Mac that built it (macOS trusts what you build locally). To hand the app to other Macs it must be signed with a Developer ID certificate and notarized: `tools/make-dmg.sh --sign "Developer ID Application: <name> (<team id>)" --notarize <notarytool profile>` produces a notarized, stapled `build/BlueSteer-<version>.dmg` (the profile comes from `xcrun notarytool store-credentials`). During development `cd apps/host && swift build && .build/debug/BlueSteerHost` runs the bare binary (no app icon, no login item, prints link events on stderr).

### Remote on Android

```bash
cd apps/remote
flutter pub get
flutter build apk --release
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

Or `flutter run` with the phone attached. Release builds are signed with the debug key until you add your own keystore (`docs/store/beta-checklist.md` has the steps for Play).

### Remote on iPhone

The bundle id `app.devland.bluesteer.client.ios` and the team in `ios/Runner.xcodeproj` belong to the maintainer, so first open `ios/Runner.xcworkspace` in Xcode and set your own team and a bundle id of your own under Signing & Capabilities (a free Apple ID works for your own devices). Then:

```bash
cd apps/remote
flutter build ios --release
xcrun devicectl device install app --device <id from: xcrun devicectl list devices> build/ios/iphoneos/Runner.app
```

A debug build (`flutter run`) only runs while `flutter run` stays attached.

### Another Mac as the remote

`bluesteer` sits next to the host binary (`build/BlueSteer.app/Contents/MacOS/bluesteer`, or `apps/host/.build/debug/bluesteer` after `swift build`). Copy it to the other Mac and run it from a terminal app; a process started over ssh gets no Bluetooth permission.

```bash
bluesteer pair                   # nearby Macs → compare the code; or: bluesteer pair 'bluesteer://pair?…'
bluesteer connect                # attach this terminal; Ctrl-] detaches
```

### First run

On the Mac open **Pair a remote…** in the menu. On the phone tap **+**, then either scan the QR code or pick the Mac from the nearby list and confirm that both screens show the same 6-digit code. Tap the Mac: a terminal opens. "New terminal" starts another shell; exited ones disappear from the list. **Install Claude Code hooks…** in the Mac's menu lets the phone show when Claude is waiting for input or for permission; **Disconnect all** drops every remote and stops accepting connections until you choose **Accept remotes again**.

### Tests

`swift test` in `apps/host` (including a 50-cycle in-process soak) and `packages/BlueSteerProtocol`, `dart test` in `packages/bluesteer_protocol_dart`, `flutter analyze` and `flutter test` in `apps/remote`, `tools/gen-proto.sh --check` for schema drift, `tools/interop-test.sh` for Swift↔Dart handshakes. `tools/soak/README.md` describes the long-run test with real phones and radio drops.

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
