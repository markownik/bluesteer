# Architecture overview

The full plan, including research findings and phases, is in `PLAN.md`. This page is the short version.

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
| `tools` | `pty-recorder`, `term-bench`, `ble-bench-peripheral`, the Flutter `ble-bench-central`, `ios-ui-driver` (an XCUITest bundle that taps, types, swipes and screenshots the remote on a USB-connected iPhone from the Mac), `render-icon.swift`, `bundle-app.sh` |
| `assets/icon` | the brand icon sources (SVG) and the rendered macOS icon |

## Session sources

1. Host-spawned: the host runs the user's login shell in a PTY (v1; agent presets come later). Exited sessions are dropped after their last output is flushed.
2. Wrapped: `bluesteer run claude` in your own terminal; the PTY output is also streamed to the host over a Unix socket.
3. Attached and discovered sessions (`claude attach`, `claude agents --json`) are deferred to v1.1; the proto keeps their fields reserved.

For every session the host polls the process's working directory every 2 s and broadcasts `SessionState` when it changes, so remotes can show where the shell is.

## Pairing

The host's "Pair a remote…" window opens a 2-minute pairing window (STATUS characteristic bit 0) and shows a QR code. The remote either scans it (link with a one-time PSK, `Noise_XXpsk3`) or picks the Mac from a nearby list and both sides compare a 6-digit code derived from the Noise handshake hash, confirming on the phone and on the Mac (`SPEC.md` §2.0–2.1). The remote's first message is `RemoteHello` with its device name (Settings on the phone, the hostname for the console remote), which the host stores with the key and shows in its menu.

## What Claude is doing (hooks)

"Install Claude Code hooks…" in the menu (or `bluesteer hooks install`) adds `bluesteer hook <Event>` command hooks to `~/.claude/settings.json` for `Notification`, `Stop`, `UserPromptSubmit`, `SessionStart` and `SessionEnd`. The hook reads `BLUESTEER_SESSION` from its environment (set by the host for its PTYs and by `bluesteer run`), forwards the event over the wrapper socket and exits; sessions BlueSteer does not bridge cost nothing. The hub maps the events to `SessionState.status` and remotes show "waiting for input" or "needs permission" next to the working directory, with the dot blue while Claude works and orange while it waits for permission. Hooks are not notifications: nothing is pushed to a backgrounded phone in v1.

## Background and reconnect

Remotes reconnect by themselves after a Bluetooth drop (direct reconnect, then scan; backoff up to 10 s) and re-subscribe, which brings a fresh snapshot with up to 500 lines of history. In the background the phone keeps the link (iOS `bluetooth-central` mode; an Android foreground service with its mandatory persistent notification), unsubscribes while hidden and re-subscribes on return, so coming back needs no handshake.

## Console remote

`bluesteer pair` (nearby Macs, code comparison, or a pasted `bluesteer://pair` link), `bluesteer hosts` and `bluesteer connect [name] [--new]` make another Mac a remote: the terminal you run it in attaches to a session on the host, keystrokes and resizes go through, Ctrl-] detaches, and a dropped link reconnects. State lives in `~/Library/Application Support/BlueSteer/remote.json`.

## Audit log and login item

The host appends connects, disconnects, pairings, revocations, session starts/exits and hook installs to `~/Library/Application Support/BlueSteer/audit.log` (0600, rotated at 5 MB; "Show audit log" in the menu). "Start at login" uses `SMAppService` and works from the bundled app (`tools/bundle-app.sh`), not from a bare `swift build` binary.

## Building

- Host and tools: Swift Package Manager, macOS 14+, Xcode 16+ (`swift build` in `apps/host` and `tools`). `tools/bundle-app.sh` wraps the host executable into a signed `.app`.
- Remote: Flutter stable (`flutter run` in `apps/remote`). On iOS a debug build only runs while `flutter run` is attached; to run it on its own use `flutter build ios --release` and install with `xcrun devicectl device install app`.

## Debugging

The host prints link events and every message it receives (except keystrokes) on stderr. `BlueSteerHost --pair` opens the pairing window's logic without the window and confirms code pairings by itself (printing the code); `--login-item on|off|status` drives the login item. `tools/ios-ui-driver/driver.sh` taps, types, swipes, presses Home and screenshots the remote on a USB-connected iPhone; on Android use `adb` (`input text`, `uiautomator dump` sees the Flutter texts, `screencap`, `svc bluetooth disable|enable` for drop tests). `blueutil -p 0|1` toggles the Mac's Bluetooth.
