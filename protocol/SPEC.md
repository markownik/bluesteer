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
| `STATUS` | `7B5E5A6E-0005-4B1E-9C0E-5A2D2E1F0001` | read | host state flags |

`INFO` value: `[u8 protocol_version][16 bytes host instance id][UTF-8 display name]`.

`STATUS` value: one flags byte. Bit 0 is set while the host's pairing window is open (it accepts new remotes, §2.1). A remote reads it before offering to pair by code, so it can tell the user to open "Pair a remote…" on the Mac instead of timing out.

Advertising data carries the service UUID; the scan response carries the local name `BlueSteer <hostname>`.

### 1.2 Chunking

Each stream is split into chunks no larger than the peer can accept: on the host, `CBCentral.maximumUpdateValueLength`; on the remote, the negotiated write-without-response length. Chunks carry no header. A receiver simply appends chunk payloads to its stream buffer.

Flow control: the host sends the next chunk only after the previous `updateValue` succeeded, and waits for `peripheralManagerIsReady(toUpdateSubscribers:)` when it fails. The remote serialises its writes.

## 2. Pairing and handshake

All application data is encrypted with the Noise Protocol Framework. Static keys are Curve25519; the cipher is ChaCha20-Poly1305; the hash is SHA-256.

### 2.0 Handshake selector

The first byte the remote writes on a new connection selects the handshake; the framed Noise message 1 follows in the same or a later chunk:

| Byte | Mode | Pattern | Host accepts |
|---|---|---|---|
| `0x01` | pair with the QR code's PSK | `Noise_XXpsk3_25519_ChaChaPoly_SHA256` | any static key, while the pairing window is open |
| `0x02` | already paired | `Noise_XX_25519_ChaChaPoly_SHA256` | static keys in its paired list |
| `0x03` | pair by code | `Noise_XX_25519_ChaChaPoly_SHA256` | any static key, while the pairing window is open; application traffic waits for §2.1b |

The prologue is always `"bluesteer/1"`. A host that is not in pairing mode ignores a connection that selects `0x01` or `0x03`; the remote times out. A selector the host does not know is a protocol error.

### 2.1 First contact (pairing)

Pairing starts on the Mac ("Pair a remote…" opens the pairing window) and ends when one remote has paired or the window closes. Two ways exist.

**(a) QR code.** The host shows `bluesteer://pair?v=1&id=<host instance id, base64url>&psk=<32 random bytes, base64url>&name=<display name>`. The remote scans it (or receives it as a link), connects, writes selector `0x01` and runs `Noise_XXpsk3` with that PSK. If the handshake succeeds both sides store the peer's static key and the PSK is discarded; a failure aborts the connection and the host regenerates the PSK.

**(b) Code comparison.** The remote lists nearby hosts, the user picks the Mac, the remote checks `STATUS` bit 0, writes selector `0x03` and runs `Noise_XX`. After the handshake both sides derive the pairing code from the Noise handshake hash `h`:

```
code = big-endian u32 of SHA256("bluesteer pair code" || h)[0..4]  mod 1_000_000
```

shown as six digits (`482 913`). The remote sends `RemoteHello`, then displays the code. The host displays the code and the remote's device name. The user confirms on both ends: the remote sends `PairConfirm{cmd_id}`; the Mac's user clicks "Pair". When the host has both, it stores the key and sends `HostHello`; the remote stores the host key when `HostHello` arrives after its own confirmation. If the Mac's user rejects, the host answers `Ack{cmd_id, ok:false}` and the remote disconnects. Until the host has sent `HostHello` it ignores every other message on that connection, and the pairing window closes it after 2 minutes. A code derived from `h` differs between the two halves of a man-in-the-middle, so a matching pair of codes proves the two devices share one handshake (the same construction as Bluetooth numeric comparison). An 8-digit typed code was dropped: it could be brute-forced offline from one captured handshake message.

### 2.2 Later connections

The remote writes selector `0x02` and starts `Noise_XX_25519_ChaChaPoly_SHA256` as initiator. The host rejects a handshake whose remote static key is not in its paired list. The remote rejects a host static key that differs from the one stored at pairing. Both checks happen as soon as the peer's static key is decrypted, before any application payload is accepted.

### 2.4 Hellos

Handshake payloads are empty. The remote's first transport message is always `RemoteHello{protocol_version, device_name, app_version}`; the host stores `device_name` with the paired key (at pairing) and updates it on later connections. The host's first transport message is `HostHello`, sent as soon as the handshake completes in modes `0x01` and `0x02`, and only after both confirmations in mode `0x03`.

### 2.3 Why not BLE pairing

Requiring encrypted GATT attributes forces operating-system pairing with different user interfaces on each platform and "Just Works" association on some of them. Keeping attributes open and authenticating at the application layer gives one consistent flow and mutual authentication on every platform.

## 3. Transport framing

After the handshake, every application message is one Noise transport message, framed as:

```
[u16 big-endian length][Noise ciphertext of that length]
```

The plaintext of a transport message is at most 4096 bytes. A larger `Envelope` is split by the sender into several transport messages of a `Fragment` wrapper (`Envelope` field reserved for v1.1; v1 senders keep envelopes under the limit by chunking `TermOutput` and `TermSnapshot` payloads).

Nonces are the Noise cipher-state counters, so frames must be encrypted in the order they are sent and decrypted in the order they are received; an implementation with asynchronous crypto has to serialize these operations (decrypting two BLE chunks concurrently reuses a nonce). A receiver treats a decryption failure as a protocol error and disconnects.

## 4. Messages

Every transport message plaintext is exactly one serialised `bluesteer.v1.Envelope`.

### 4.1 Session lifecycle

- After the handshake the host sends `SessionList`. It sends `SessionState` whenever a session changes; an exited session is reported once with status `EXITED` and then dropped from the host's list. `SessionState.cwd` is the current directory of the session's process (the host polls it every 2 s), so it follows `cd`.
- `NewSession{preset, rows, cols}` starts a session. Version 1 hosts accept only `preset = "shell"` (the user's login shell in their home directory). The `Ack` carries the new `session_id`; the remote then subscribes to it.
- `Subscribe{session_id, rows, cols, scrollback_lines}` asks for a session's screen. The host replies with `Ack`, then a `TermSnapshot`, then a stream of `TermOutput`. For host-spawned and attached sessions the PTY is resized to `rows × cols` first; for wrapped sessions the size stays with the user's terminal and the snapshot reports the real size. The first snapshot of a subscription carries up to `scrollback_lines` lines of history before the screen (§4.4); later snapshots of the same subscription (§5) carry only the screen, so the remote's accumulated history survives them.
- `SessionState.status` for a shell session is `BUSY` unless the host learns more from Claude Code hooks relayed by `bluesteer hook` (see `docs/architecture.md`): `UserPromptSubmit` → `BUSY`, `Notification` with `permission_prompt` → `WAITING_PERMISSION`, `Notification` with `idle_prompt`, `Stop` and `SessionStart` → `WAITING_INPUT`, `SessionEnd` → `IDLE`. Remotes show a label for `WAITING_INPUT` and `WAITING_PERMISSION` only.
- `TermInput` writes bytes to the session's PTY. The host does not acknowledge individual inputs.
- `Unsubscribe` stops the output stream. A disconnect unsubscribes everything.

### 4.2 Output stream and sequence numbers

`TermOutput.seq` increases by one per message per session and restarts from the snapshot's `seq`. If a remote detects a gap it re-subscribes. The host may at any time replace pending output with a new `TermSnapshot` (see §5).

### 4.3 Compression

`TermSnapshot.vt` is compressed with raw deflate (no zlib header) when `compressed` is true. `TermOutput.data` chunks with `compressed` set are consecutive pieces of one raw-deflate stream per subscription, flushed with a sync flush at every message so each chunk can be inflated as it arrives. A new snapshot resets that stream.

### 4.4 Snapshot contents

A snapshot is a VT byte sequence the remote feeds to its emulator. It starts with `ESC[0m ESC[H ESC[2J` (erase the screen, keep history), then each row as a cursor move, SGR runs and text, and ends with the cursor position and the modes that affect input (application cursor keys, bracketed paste). When history is included it comes first: `ESC[0m ESC[2J ESC[3J ESC[<rows>;1H` (also erase the remote's history, park the cursor on the last row), then each history line as SGR runs, text, `ESC[0m` and CR LF so that every line scrolls into the remote's history, then `rows − 1` line feeds to clear the viewport, then the screen as above.

## 5. Backpressure

The host keeps, per subscription, a bounded queue of un-sent output (16 KiB plaintext by default). When the queue would overflow, the host drops it and enqueues a fresh `TermSnapshot` instead. The remote only ever needs the latest screen, so no output is ever "lost" from the user's point of view, only intermediate frames.

## 6. Reconnection

On a BLE disconnect the remote reconnects (immediately, then with exponential backoff up to 10 s), runs the §2.2 handshake, and re-subscribes to the sessions it was viewing. The host answers with fresh snapshots. Sessions keep running on the host regardless of remote connectivity.

## 7. Versioning

`INFO` and `HostHello` carry `protocol_version`. A remote that does not implement the host's version shows "update required" and disconnects. Within a version, new optional fields may be added to messages; semantics of existing fields never change. Breaking changes bump the version and are listed in `CHANGELOG.md`.

## 8. Security considerations

See `docs/threat-model.md`. In short: pairing is the trust boundary; a paired remote is a full terminal on the host.
