# Protocol changelog

Breaking wire changes bump `protocol_version` (advertised in the `INFO` characteristic and `HostHello`).

## 1 (unreleased)

- Initial protocol: GATT service, Noise XX / XXpsk3 handshake, 2-byte length-prefixed transport messages, protobuf `Envelope`.
- `Ack.session_id` added (the session started by a `NewSession`). `NewSession.preset` is `"shell"` only in v1; `args` and `low_bandwidth` are reserved.
- `SessionState.cwd` is the session process's current directory, refreshed by the host every 2 s.
