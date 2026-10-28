# BlueSteer

Offline Bluetooth Low Energy terminal bridge for Claude Code, GitHub Copilot CLI and any other terminal agent.

A **Host** app on your Mac runs the agent session in a pseudo-terminal and advertises it over BLE. A **Remote** app on a phone or another computer, with no internet connection at all, attaches to that session as a real terminal: it sees the screen and types into it. Nothing goes through a relay server and nothing leaves the room.

Status: Phase 0 (feasibility spikes). See `docs/` for the plan and threat model as they land.

## Layout

- `protocol/` wire protocol spec, protobuf schema, test vectors
- `apps/host/` macOS host app and `bluesteer` command line tool (Swift)
- `apps/remote/` remote app (Flutter: iOS, Android, macOS; Windows later)
- `tools/` development tools: PTY recorder, bandwidth bench, BLE throughput bench
- `docs/` plan, threat model, user documentation

## License

Apache-2.0. See `LICENSE`.
