# Threat model (draft)

BlueSteer gives a paired remote device a real terminal on the host Mac. The security goal is therefore simple to state: **only devices the user explicitly paired can connect, and nobody else can read or alter the traffic.**

## Assets

- The agent session (ability to run commands as the user).
- Terminal content (source code, secrets printed on screen).
- Pairing keys.

## Adversaries and mitigations

| Adversary | Capability | Mitigation |
|---|---|---|
| Nearby attacker during pairing | Connects before the real remote and tries to pair | First handshake requires the PSK from the QR code (`Noise_XXpsk3`); host shows a confirmation; PSK is single-use |
| Nearby eavesdropper / active MITM | Reads or alters BLE traffic | Noise XX with pinned static keys, ChaCha20-Poly1305, per-direction nonce counters; decryption failure disconnects |
| Attacker with a stolen remote | Uses the paired phone | Host-side revoke list (menu → Paired remotes). "Unlock before connecting" in the remote's Settings asks for Face ID, fingerprint or the passcode (the OS prompt via `local_auth`) every time a Mac is opened; off by default. "Disconnect all" in the menu sends every connected remote a `HostGoodbye`, drops the links, withdraws the GATT service and stops advertising until "Accept remotes again"; remotes that received the goodbye stop reconnecting until their user asks |
| Attacker with a stolen host key | Impersonates the host to the remote | `pairing.json` is 0600 in the user's 0700 support directory; revoking and re-pairing replaces keys. Moving the key into the Keychain waits for Developer ID signing: an ad-hoc signed build changes its code identity on every rebuild, so Keychain ACLs would prompt at every start |
| Local attacker on the Mac (other user) | Talks to the wrapper/hook socket | Socket in `~/Library/Application Support/BlueSteer/` (0700) with 0600 permissions, and the host accepts only peers whose uid is its own (`getpeereid`); no network listeners. The per-install token once planned was dropped: any same-user process could read it, and the kernel's peer credentials cover the other-user case |
| Anyone at the Mac after the host app quits | Session helpers keep shells running | By design (sessions survive a host restart); they run as the user, like any terminal left open. `exit` ends them |
| Supply chain | Tampered builds | Signed, notarized builds reproducible from the public repo; pinned dependencies |

## Out of scope

- Compromise of the Mac itself (the remote cannot do more than the local user).
- Denial of service by radio jamming.
- Side channels in BLE timing.

## Residual risks

- The Noise implementation is hand-written in Swift and Dart (no audited library exists for either). Cross-language test vectors reduce the risk; an external review is planned after launch.
- Terminal content is visible on the remote's screen; shoulder surfing is the user's responsibility.
