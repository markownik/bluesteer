# Protocol changelog

Breaking wire changes bump `protocol_version` (advertised in the `INFO` characteristic and `HostHello`).

## 1 (unreleased)

- Initial protocol: GATT service, Noise XX / XXpsk3 handshake, 2-byte length-prefixed transport messages, protobuf `Envelope`.
