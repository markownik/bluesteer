/// BlueSteer wire protocol: framing, Noise handshake and generated messages.
///
/// Mirrors `packages/BlueSteerProtocol` (Swift). Both must pass the vectors in
/// `protocol/testvectors/`.
library;

export 'src/framing.dart';
export 'src/noise/noise_handshake.dart';
export 'src/secure_channel.dart';
export 'src/generated/bluesteer.pb.dart';
export 'src/generated/bluesteer.pbenum.dart';
export 'src/protocol_version.dart';
