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
| Attacker with a stolen remote | Uses the paired phone | Optional biometric gate before connecting; host-side revoke list; "disconnect all" in the menu bar |
| Attacker with a stolen host key | Impersonates the host to the remote | Keys live in Keychain; revoking and re-pairing replaces them |
| Local attacker on the Mac (other user) | Talks to the wrapper/hook socket | Socket in `~/Library/Application Support/BlueSteer/` with 0600 permissions and a per-install token; no network listeners |
| Supply chain | Tampered builds | Signed, notarized builds reproducible from the public repo; pinned dependencies |

## Out of scope

- Compromise of the Mac itself (the remote cannot do more than the local user).
- Denial of service by radio jamming.
- Side channels in BLE timing.

## Residual risks

- The Noise implementation is hand-written in Swift and Dart (no audited library exists for either). Cross-language test vectors reduce the risk; an external review is planned after launch.
- Terminal content is visible on the remote's screen; shoulder surfing is the user's responsibility.
