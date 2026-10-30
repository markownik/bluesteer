# BlueSteer

Offline Bluetooth Low Energy terminal bridge for Claude Code, GitHub Copilot CLI and any other terminal agent.

A **Host** app on your Mac runs the agent session in a pseudo-terminal and advertises it over BLE. A **Remote** app on a phone or another computer, with no internet connection at all, attaches to that session as a real terminal: it sees the screen and types into it. Nothing goes through a relay server and nothing leaves the room.

Status: version 1.0 works end to end on macOS + Android + iOS: pair by QR code or by comparing a 6-digit code, open a login shell on the Mac from the phone, type into it, scroll back through its history, mirror a terminal you started yourself with `bluesteer run`, see when Claude is waiting for input or for permission, lose and regain the link without doing anything (a few seconds after the radio is back), and keep your sessions across a restart of the host app. Another Mac can be a remote too (`bluesteer connect`). In v1 the remote opens plain shells only; you run `claude` or `copilot` inside them. The App Store and Google Play submissions of the phone apps are in progress.

## Get it

- **BlueSteer Host** (macOS 14+, menu bar): free. The signed and notarized DMG is published with each release at https://github.com/markownik/bluesteer/releases, with its SHA-256 in the release notes. Everything needed to build it yourself is below.
- **BlueSteer Remote** (iPhone, Android): free on the App Store and Google Play once published; buildable from this repository too.
- **Another Mac as the remote:** the `bluesteer` command line tool that ships inside the host app.
- **Support the project:** BlueSteer is free software; if it is useful to you, https://github.com/sponsors/markownik funds the developer accounts, the test devices and the next features.

Website https://bluesteer.devland.app · [get started and support](https://bluesteer.devland.app/support) · [security overview](https://bluesteer.devland.app/security) · [privacy](https://bluesteer.devland.app/privacy) · [terms](https://bluesteer.devland.app/terms) · support@devland.app

## Build from source

Prerequisites:

- macOS 14 or newer with Xcode 16 or newer (Swift 5.9+). The host is a Swift package; no Xcode project is needed.
- Flutter stable (3.47 is what the apps are built with; `flutter doctor` must be happy for Android and/or iOS).
- A phone with Bluetooth Low Energy: Android 12+ or iOS 16+.
- No protobuf compiler: the generated code is committed. Only after editing `protocol/bluesteer.proto` you need `protoc`, `brew install swift-protobuf` and `dart pub global activate protoc_plugin`, then `tools/gen-proto.sh`.

### Host (the Mac you want to steer)

```bash
git clone https://github.com/markownik/bluesteer && cd bluesteer
tools/bundle-app.sh              # builds build/BlueSteer.app (release, ad-hoc signed)
open build/BlueSteer.app         # menu-bar icon; macOS asks for Bluetooth once
```

An ad-hoc signed app runs on the Mac that built it. `tools/make-dmg.sh --sign "Developer ID Application: <name> (<team id>)" --notarize <notarytool profile>` produces the notarized, stapled `build/BlueSteer-<version>.dmg` that the releases ship. During development `cd apps/host && swift build && .build/debug/BlueSteerHost` runs the bare binary (no app icon, no login item, prints link events on stderr).

### Remote on Android

```bash
cd apps/remote
flutter pub get
flutter build apk --release
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

Or `flutter run` with the phone attached. Release builds are signed with the debug key until you add your own keystore (the standard Flutter release-signing set-up).

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

### Get started

The same steps, in the apps' own words, are at https://bluesteer.devland.app/support.

1. **On the Mac** open BlueSteer and choose **Pair a remote…** from the menu. A QR code appears, valid for 2 minutes or until a remote pairs.
2. **On the phone** tap **+**. Scan the QR code, or pick your Mac from the nearby list (**Tap to pair by code**); both screens then show the same 6-digit code: tap **It matches** on the phone and **Pair** on the Mac.
3. **Tap the Mac** in the list: a terminal opens (your login shell, on the Mac). Type `claude`. The key bar has Esc, Tab, ⇧Tab, ^C, ^D, ↑ ↓ ← → and ⏎. **New terminal** starts another shell; exited ones disappear from the list.
4. Optional: **Install Claude Code hooks…** in the Mac's menu shows on the phone when Claude is working, waiting for input or waiting for permission. **Unlock before connecting** in the phone's Settings asks for Face ID, fingerprint or the passcode each time a Mac is opened. **Disconnect all** drops every remote and stops accepting connections until you choose **Accept remotes again**; **Paired remotes** → **Revoke** removes a device, **Forget** (press and hold) does the same on the phone.
5. A terminal you started yourself is shared with `bluesteer run claude`; another Mac attaches with `bluesteer pair` and `bluesteer connect`.

### Tests

`swift test` in `apps/host` (including a 50-cycle in-process soak) and `packages/BlueSteerProtocol`, `dart test` in `packages/bluesteer_protocol_dart`, `flutter analyze` and `flutter test` in `apps/remote`, `tools/gen-proto.sh --check` for schema drift, `tools/interop-test.sh` for Swift↔Dart handshakes. `tools/soak/README.md` describes the long-run test with real phones and radio drops.

**Demo mode** (`flutter run --dart-define=BLUESTEER_DEMO=true`) runs the remote against a scripted Mac inside the app (`lib/demo/demo.dart`): two paired Macs, three terminals, a Claude Code permission prompt, pairing by code. It needs no host, Bluetooth or camera, so it runs in the iOS simulator; `tools/store-shots.sh` drives it through every screen with `integration_test/screenshots_test.dart` and writes the store screenshots to `docs/store/screenshots/`.

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
- `docs/` architecture overview, threat model

## License

Apache-2.0. See `LICENSE`.
