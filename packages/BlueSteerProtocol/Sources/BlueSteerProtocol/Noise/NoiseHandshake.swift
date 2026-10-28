import Foundation

// Noise_XX_25519_ChaChaPoly_SHA256 and Noise_XXpsk3 (SPEC.md §2), built on
// CryptoKit. Implemented in Phase 1 against protocol/testvectors/noise.
//
// Planned surface:
//   NoiseHandshake(role:, staticKey:, psk:, prologue:)
//   .writeMessage(payload:) -> Data / .readMessage(_:) -> Data
//   .remoteStaticKey (available after the peer's static key is decrypted)
//   .split() -> (send: NoiseCipherState, receive: NoiseCipherState)
