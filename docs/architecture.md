# Architecture overview

The full plan, including research findings and phases, is in `PLAN.md`. This page is the short version.

```
Mac (Host)                                              Phone / laptop (Remote)
──────────────────────────────────────────              ─────────────────────────
agent CLI in a PTY  ──► headless SwiftTerm ──► deflate  ─BLE─► inflate ──► xterm view
(claude, copilot,        (screen state,        + Noise         + Noise      (screen)
 shell, ...)              snapshots)
        ▲                                                            │
        └──────────────── TermInput (keystrokes) ◄───────────────────┘
```

## Components

| Path | What it is |
|---|---|
| `protocol/` | Wire protocol: `SPEC.md`, `bluesteer.proto`, conformance vectors |
| `packages/BlueSteerProtocol` | Swift: Noise handshake/transport, framing, generated protobuf |
| `packages/bluesteer_protocol_dart` | Dart: the same, for the remote |
| `apps/host` | macOS menu-bar app (`BlueSteerHost`), shared `HostCore`, and the `bluesteer` command line tool (`run`, `hook`, `sessions`, `status`) |
| `apps/remote` | Flutter remote app |
| `tools` | `pty-recorder`, `term-bench`, `ble-bench-peripheral` and the Flutter `ble-bench-central` |

## Session sources

1. Host-spawned: the host runs the user's login shell in a PTY (v1; agent presets come later).
2. Wrapped: `bluesteer run claude` in your own terminal; the PTY output is also streamed to the host.
3. Attached: the host runs `claude attach <id>` for a Claude background session.
4. Discovered: listed from `claude agents --json`, not bridged.

## Building

- Host and tools: Swift Package Manager, macOS 14+, Xcode 16+ (`swift build` in `apps/host` and `tools`). `tools/bundle-app.sh` wraps the host executable into a signed `.app`.
- Remote: Flutter stable (`flutter run` in `apps/remote`).
