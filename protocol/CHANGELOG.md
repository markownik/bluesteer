# Protocol changelog

Breaking wire changes bump `protocol_version` (advertised in the `INFO` characteristic and `HostHello`).

## 1 (unreleased)

- Initial protocol: GATT service, Noise XX / XXpsk3 handshake, 2-byte length-prefixed transport messages, protobuf `Envelope`.
- `Ack.session_id` added (the session started by a `NewSession`). `NewSession.preset` is `"shell"` only in v1; `args` and `low_bandwidth` are reserved.
- `SessionState.cwd` is the session process's current directory, refreshed by the host every 2 s.
- Handshake selector byte before Noise message 1 (`0x01` QR PSK, `0x02` paired, `0x03` pair by code); pairing by code comparison derived from the handshake hash; `RemoteHello` (31) and `PairConfirm` (32); `STATUS` characteristic with the pairing flag. The 8-digit typed code is gone.
- `Subscribe.scrollback_lines`: history lines in the first snapshot of a subscription.
- `SessionState.status` driven by Claude Code hooks (`bluesteer hook`).
