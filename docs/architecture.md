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
| `apps/host` | macOS menu-bar app (`BlueSteerHost`), shared `HostCore`, and the `bluesteer` command line tool (`run` works; `hook`, `sessions`, `status` are stubs for Phase 3) |
| `apps/remote` | Flutter remote app |
| `tools` | `pty-recorder`, `term-bench`, `ble-bench-peripheral`, the Flutter `ble-bench-central`, and `ios-ui-driver` (an XCUITest bundle that taps, types and screenshots the remote on a USB-connected iPhone from the Mac) |

## Session sources

1. Host-spawned: the host runs the user's login shell in a PTY (v1; agent presets come later). Exited sessions are dropped after their last output is flushed.
2. Wrapped: `bluesteer run claude` in your own terminal; the PTY output is also streamed to the host over a Unix socket.
3. Attached (planned, Phase 3): the host runs `claude attach <id>` for a Claude background session.
4. Discovered (planned, Phase 3): listed from `claude agents --json`, not bridged.

For every session the host polls the process's working directory every 2 s and broadcasts `SessionState` when it changes, so remotes can show where the shell is.

## Building

- Host and tools: Swift Package Manager, macOS 14+, Xcode 16+ (`swift build` in `apps/host` and `tools`). `tools/bundle-app.sh` wraps the host executable into a signed `.app`.
- Remote: Flutter stable (`flutter run` in `apps/remote`).
