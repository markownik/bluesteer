# Architecture overview

This page is the short version of the design.

```
Mac (Host)                                              Phone / laptop (Remote)
──────────────────────────────────────────              ─────────────────────────
login shell in a PTY ──► headless SwiftTerm ──► deflate  ─BLE─► inflate ──► xterm view
(run claude, copilot,     (screen state,        + Noise         + Noise      (screen)
 anything inside it)       snapshots)
        ▲                                                            │
        └──────────────── TermInput (keystrokes) ◄───────────────────┘
```

## Components

| Path | What it is |
|---|---|
| `protocol/` | Wire protocol: `SPEC.md`, `bluesteer.proto`, conformance vectors |
| `packages/BlueSteerProtocol` | Swift: Noise handshake/transport, framing, generated protobuf |
| `packages/bluesteer_protocol_dart` | Dart: the same, for the remote |
| `apps/host` | macOS menu-bar app (`BlueSteerHost`), shared `HostCore`, `RemoteCore` (the console remote) and the `bluesteer` command line tool (`run`, `hook`, `hooks`, `pair`, `hosts`, `connect`) |
| `apps/remote` | Flutter remote app |
| `tools` | `pty-recorder`, `term-bench` (on HostCore's snapshot renderer), `ble-bench-peripheral`, the Flutter `ble-bench-central`, `ios-ui-driver` (an XCUITest bundle that taps, types, swipes and screenshots the remote on a USB-connected iPhone from the Mac), `soak/` (the long-run test, see its README), `render-icon.swift`, `bundle-app.sh` |
| `assets/icon` | the brand icon sources (SVG) and the rendered macOS icon |

## Session sources

1. Host-spawned: the host starts the user's login shell in a detached helper process (`bluesteer serve-session`, spawned with its own session group and no inherited descriptors) that owns the PTY and talks to the host over the wrapper socket. The shell therefore outlives the host app: after a relaunch the helper re-attaches within a second, sends its screen (with history) so the host's emulator is rebuilt, and remotes re-subscribe to the same session id. The host answers `NewSession` once the helper has reported back. Exited sessions are dropped after their last output is flushed; a helper whose host is away keeps the shell running and retries every second.
2. Wrapped: `bluesteer run claude` in your own terminal; the wrapper owns the PTY and streams its output to the host over the same socket, re-attaching with its screen whenever a host (re)appears. A host quit never ends the wrapped command.
3. Attached and discovered sessions (`claude attach`, `claude agents --json`) are deferred to v1.1; the proto keeps their fields reserved.

For every session the host polls the process's working directory every 2 s and broadcasts `SessionState` when it changes, so remotes can show where the shell is.

## Pairing

The host's "Pair a remote…" window opens a 2-minute pairing window (STATUS characteristic bit 0) and shows a QR code. The remote either scans it (link with a one-time PSK, `Noise_XXpsk3`) or picks the Mac from a nearby list and both sides compare a 6-digit code derived from the Noise handshake hash, confirming on the phone and on the Mac (`SPEC.md` §2.0–2.1). The remote's first message is `RemoteHello` with its device name (Settings on the phone, the Computer Name for the console remote), which the host stores with the key and shows in its menu. Phones do not get the Mac's name from its advertisement (a macOS peripheral sends no local name next to the service UUID; scan results carry only the cached "Mac"), so the pairing page reads each nearby Mac's Computer Name from `INFO`, and the saved name follows `HostHello` on every connection.

## What Claude is doing (hooks)

"Install Claude Code hooks…" in the menu (or `bluesteer hooks install`) adds `bluesteer hook <Event>` command hooks to `~/.claude/settings.json` for `Notification`, `Stop`, `UserPromptSubmit`, `SessionStart` and `SessionEnd`. The hook reads `BLUESTEER_SESSION` from its environment (set by the host for its PTYs and by `bluesteer run`), forwards the event over the wrapper socket and exits; sessions BlueSteer does not bridge cost nothing. The hub maps the events to `SessionState.status` and remotes show "waiting for input" or "needs permission" next to the working directory, with the dot blue while Claude works and orange while it waits for permission. Hooks are not notifications: nothing is pushed to a backgrounded phone in v1.

## Background and reconnect

Remotes reconnect by themselves after a Bluetooth drop: they scan for the Mac again (its address rotates) with 0, 2, 4, 8 and then 10 s between attempts, wait while their own radio is off and try the moment it is back, then re-run the handshake and re-subscribe, which brings a fresh snapshot with up to 500 lines of history. On the Samsung this takes 2–4 s after its radio restarts (it was ~22 s). The BLE link and the scan sit behind small `Link`/`Transport` interfaces so the reconnect logic has unit tests with an in-memory Mac. In the background the phone keeps the link (iOS `bluetooth-central` mode; an Android foreground service with its mandatory persistent notification), unsubscribes while hidden and re-subscribes on return, so coming back needs no handshake. A backgrounded iOS app gets scan results slowly, so while it is not in the foreground a reconnect attempt is one long window (5 minutes) in which a direct connect to the Mac's last known device id stays pending next to the scan: iOS completes it as soon as the Mac advertises again (3.5 s after a Mac radio restart), and the scan still covers a rotated address. A session that is gone ends the terminal page with a "New terminal" action.

"Disconnect all" in the host's menu is the panic button: the host sends `HostGoodbye` to every connected remote, drops the links, removes its GATT service and stops advertising (a BLE peripheral cannot cut a central's connection itself, but a central whose service vanished fails on its next write and drops the link). The menu then shows "Not accepting remotes" until "Accept remotes again". A phone that received the goodbye shows "Disconnected by <Mac>" with a Reconnect button instead of its reconnect loop; the console remote prints the reason and exits.

## Console remote

`bluesteer pair` (nearby Macs, code comparison, or a pasted `bluesteer://pair` link), `bluesteer hosts` and `bluesteer connect [name] [--new]` make another Mac a remote: the terminal you run it in attaches to a session on the host, keystrokes and resizes go through, Ctrl-] detaches, and a dropped link reconnects. State lives in `~/Library/Application Support/BlueSteer/remote.json`. The nearby list reads each Mac's name from `INFO` (a Mac central sees no name in the advertisement at all). Run it from a terminal app: a process started over ssh gets no Bluetooth permission prompt and CoreBluetooth reports it as unauthorized. `BLUESTEER_DEBUG=1` prints link traffic on stderr.

## Audit log and login item

The host appends connects, disconnects, pairings, revocations, session starts/exits and hook installs to `~/Library/Application Support/BlueSteer/audit.log` (0600, rotated at 5 MB; "Show audit log" in the menu). "Start at login" uses `SMAppService` and works from the bundled app (`tools/bundle-app.sh`), not from a bare `swift build` binary.

## Building

- Host and tools: Swift Package Manager, macOS 14+, Xcode 16+ (`swift build` in `apps/host` and `tools`). `tools/bundle-app.sh` wraps the host executable and the `bluesteer` tool (which the host needs next to it for session helpers) into a signed `.app`. `HostCore` is also a library product so `tools/term-bench` can use the host's snapshot renderer.
- Remote: Flutter stable (`flutter run` in `apps/remote`). On iOS a debug build only runs while `flutter run` is attached; to run it on its own use `flutter build ios --release` and install with `xcrun devicectl device install app`.

## Debugging

The host prints timestamped link events (open, first handshake bytes, established) and every message it receives (except keystrokes) on stderr. Start it from a clean environment: a host launched from inside a Claude Code shell hands that session's variables to every helper shell. Quitting the host no longer ends sessions; `exit` in the terminal does. `BlueSteerHost --pair` opens the pairing window's logic without the window and confirms code pairings by itself (printing the code); `--login-item on|off|status` drives the login item. `tools/ios-ui-driver/driver.sh` taps, types, swipes, presses Home and screenshots the remote on a USB-connected iPhone; on Android use `adb` (`input text`, `uiautomator dump` sees the Flutter texts, `screencap`, `svc bluetooth disable|enable` for drop tests). `blueutil -p 0|1` toggles the Mac's Bluetooth.
