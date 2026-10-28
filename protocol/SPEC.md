# BlueSteer protocol specification (version 1, draft)

This document is the normative description of how a BlueSteer Remote talks to a BlueSteer Host over Bluetooth Low Energy. The protobuf schema in `bluesteer.proto` defines message contents; this document defines everything around it. Both implementations (`packages/BlueSteerProtocol`, `packages/bluesteer_protocol_dart`) must pass the vectors in `testvectors/`.

## 1. Roles and transport

- The **Host** (macOS) is the BLE **peripheral**. It advertises one primary service and accepts one or more **Remotes**.
- The **Remote** is the BLE **central**. It scans for the service UUID, connects, subscribes to `TX`, and writes to `RX`.
- BLE's link layer acknowledges and retransmits every data PDU, so within one connection the bytes written to `RX` and notified on `TX` form two reliable, ordered byte streams. No application-level acknowledgement is used. A disconnect ends the streams; recovery is described in §6.

### 1.1 GATT layout

| Item | UUID | Properties | Purpose |
|---|---|---|---|
| Service | `7B5E5A6E-0001-4B1E-9C0E-5A2D2E1F0001` | primary | BlueSteer |
| `TX` | `7B5E5A6E-0002-4B1E-9C0E-5A2D2E1F0001` | notify | host → remote byte stream |
| `RX` | `7B5E5A6E-0003-4B1E-9C0E-5A2D2E1F0001` | write without response | remote → host byte stream |
| `INFO` | `7B5E5A6E-0004-4B1E-9C0E-5A2D2E1F0001` | read | protocol version and host identity |

`INFO` value: `[u8 protocol_version][16 bytes host instance id][UTF-8 display name]`.

Advertising data carries the service UUID; the scan response carries the local name `BlueSteer <hostname>`.

### 1.2 Chunking

Each stream is split into chunks no larger than the peer can accept: on the host, `CBCentral.maximumUpdateValueLength`; on the remote, the negotiated write-without-response length. Chunks carry no header. A receiver simply appends chunk payloads to its stream buffer.

Flow control: the host sends the next chunk only after the previous `updateValue` succeeded, and waits for `peripheralManagerIsReady(toUpdateSubscribers:)` when it fails. The remote serialises its writes.

## 2. Pairing and handshake

All application data is encrypted with the Noise Protocol Framework. Static keys are Curve25519; the cipher is ChaCha20-Poly1305; the hash is SHA-256.

### 2.1 First contact (pairing)

1. The host shows a QR code containing `bluesteer://pair?v=1&id=<host instance id, base64url>&psk=<32 random bytes, base64url>&name=<display name>`. The same PSK is shown as an 8-digit fallback code (first 8 digits of the PSK's decimal form) for manual entry.
2. The remote connects and starts `Noise_XXpsk3_25519_ChaChaPoly_SHA256` as initiator, with the PSK from the QR code and the prologue `"bluesteer/1"`.
3. If the handshake succeeds, both sides store the peer's static public key. The host shows "Remote <name> paired" and the PSK is discarded.
4. A handshake failure aborts the connection. The host regenerates the PSK for the next pairing attempt.

The Noise payloads of handshake messages 2 and 3 carry a `HostHello` and a `RemoteHello` (device name, app version) respectively, so each side knows who it is talking to before application traffic starts.

### 2.2 Later connections

The remote starts `Noise_XX_25519_ChaChaPoly_SHA256` as initiator with the same prologue. The host rejects a handshake whose remote static key is not in its paired list. The remote rejects a host static key that differs from the one stored at pairing. Both checks happen as soon as the peer's static key is decrypted, before any application payload is accepted.

### 2.3 Why not BLE pairing

Requiring encrypted GATT attributes forces operating-system pairing with different user interfaces on each platform and "Just Works" association on some of them. Keeping attributes open and authenticating at the application layer gives one consistent flow and mutual authentication on every platform.

## 3. Transport framing

After the handshake, every application message is one Noise transport message, framed as:

```
[u16 big-endian length][Noise ciphertext of that length]
```

The plaintext of a transport message is at most 4096 bytes. A larger `Envelope` is split by the sender into several transport messages of a `Fragment` wrapper (`Envelope` field reserved for v1.1; v1 senders keep envelopes under the limit by chunking `TermOutput` and `TermSnapshot` payloads).

Nonces are the Noise cipher-state counters. A receiver treats a decryption failure as a protocol error and disconnects.

## 4. Messages

Every transport message plaintext is exactly one serialised `bluesteer.v1.Envelope`.

### 4.1 Session lifecycle

- After the handshake the host sends `SessionList`. It sends `SessionState` whenever a session changes; an exited session is reported once with status `EXITED` and then dropped from the host's list. `SessionState.cwd` is the current directory of the session's process (the host polls it every 2 s), so it follows `cd`.
- `NewSession{preset, rows, cols}` starts a session. Version 1 hosts accept only `preset = "shell"` (the user's login shell in their home directory). The `Ack` carries the new `session_id`; the remote then subscribes to it.
- `Subscribe{session_id, rows, cols}` asks for a session's screen. The host replies with `Ack`, then a `TermSnapshot`, then a stream of `TermOutput`. For host-spawned and attached sessions the PTY is resized to `rows × cols` first; for wrapped sessions the size stays with the user's terminal and the snapshot reports the real size.
- `TermInput` writes bytes to the session's PTY. The host does not acknowledge individual inputs.
- `Unsubscribe` stops the output stream. A disconnect unsubscribes everything.

### 4.2 Output stream and sequence numbers

`TermOutput.seq` increases by one per message per session and restarts from the snapshot's `seq`. If a remote detects a gap it re-subscribes. The host may at any time replace pending output with a new `TermSnapshot` (see §5).

### 4.3 Compression

`TermSnapshot.vt` is compressed with raw deflate (no zlib header) when `compressed` is true. `TermOutput.data` chunks with `compressed` set are consecutive pieces of one raw-deflate stream per subscription, flushed with a sync flush at every message so each chunk can be inflated as it arrives. A new snapshot resets that stream.

## 5. Backpressure

The host keeps, per subscription, a bounded queue of un-sent output (16 KiB plaintext by default). When the queue would overflow, the host drops it and enqueues a fresh `TermSnapshot` instead. The remote only ever needs the latest screen, so no output is ever "lost" from the user's point of view, only intermediate frames.

## 6. Reconnection

On a BLE disconnect the remote reconnects (immediately, then with exponential backoff up to 10 s), runs the §2.2 handshake, and re-subscribes to the sessions it was viewing. The host answers with fresh snapshots. Sessions keep running on the host regardless of remote connectivity.

## 7. Versioning

`INFO` and `HostHello` carry `protocol_version`. A remote that does not implement the host's version shows "update required" and disconnects. Within a version, new optional fields may be added to messages; semantics of existing fields never change. Breaking changes bump the version and are listed in `CHANGELOG.md`.

## 8. Security considerations

See `docs/threat-model.md`. In short: pairing is the trust boundary; a paired remote is a full terminal on the host.
