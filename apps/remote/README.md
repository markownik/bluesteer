# bluesteer_remote

The BlueSteer remote: a Flutter app that pairs with a Mac running the host over BLE and attaches to its terminal sessions. Protocol code comes from `../../packages/bluesteer_protocol_dart`; the design is in `../../docs/`.

- Android: `flutter run`.
- iOS: set your team in `ios/Runner.xcodeproj`, then `flutter build ios --release` and install the app with `xcrun devicectl device install app` (a debug build only runs while `flutter run` is attached).
- Tests and checks: `flutter analyze`; the protocol tests live in the package.
