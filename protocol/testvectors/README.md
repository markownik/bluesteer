# Conformance test vectors

Shared fixtures run by both the Swift (`packages/BlueSteerProtocol`) and Dart (`packages/bluesteer_protocol_dart`) test suites.

- `noise/` — Noise_XX_25519_ChaChaPoly_SHA256 and Noise_XXpsk3 handshake transcripts (keys, ephemerals, expected handshake hashes, transport ciphertexts).
- `framing/` — byte streams split at arbitrary chunk boundaries and the transport messages they must reassemble to.
- `messages/` — protobuf `Envelope` encodings with their decoded JSON form.

Files are JSON. Each vector names the spec section it exercises.
