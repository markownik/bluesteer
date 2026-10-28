import 'dart:convert';
import 'dart:typed_data';

import 'framing.dart';
import 'noise/noise_handshake.dart';

/// One end of an encrypted BlueSteer link (SPEC.md §2–3), independent of the
/// transport. Mirrors the Swift `SecureChannel`.
///
/// Handshake and transport messages all use the 2-byte length framing, so a
/// BLE byte stream can be fed in arbitrary chunks via [receive].
class SecureChannel {
  SecureChannel._(this.isHost, this._handshake, this._pairedKeys, this._pinnedHostKey, this._pairing);

  static final prologue = utf8.encode('bluesteer/1');

  /// The Mac side. [pairedKeys] are accepted remote static keys; [pairingPsk]
  /// (when set) allows one new remote to pair with `Noise_XXpsk3`.
  static Future<SecureChannel> host({
    required NoiseKeyPair staticKey,
    required Set<String> pairedKeys,
    List<int>? pairingPsk,
  }) async {
    final hs = await NoiseHandshake.create(
      pattern: pairingPsk == null ? NoisePattern.xx : NoisePattern.xxpsk3,
      initiator: false,
      prologue: prologue,
      staticKey: staticKey,
      psk: pairingPsk,
    );
    return SecureChannel._(true, hs, pairedKeys, null, pairingPsk != null);
  }

  /// A remote. [pinnedHostKey] is the host's static key from pairing;
  /// [pairingPsk] is set while pairing (from the QR code).
  static Future<SecureChannel> remote({
    required NoiseKeyPair staticKey,
    List<int>? pinnedHostKey,
    List<int>? pairingPsk,
  }) async {
    final hs = await NoiseHandshake.create(
      pattern: pairingPsk == null ? NoisePattern.xx : NoisePattern.xxpsk3,
      initiator: true,
      prologue: prologue,
      staticKey: staticKey,
      psk: pairingPsk,
    );
    return SecureChannel._(false, hs, const {}, pinnedHostKey, pairingPsk != null);
  }

  final bool isHost;
  final Set<String> _pairedKeys;
  final List<int>? _pinnedHostKey;
  final bool _pairing;
  NoiseHandshake? _handshake;
  NoiseCipherState? _send;
  NoiseCipherState? _receive;
  final Framer _framer = Framer();
  Uint8List? remoteStaticKey;
  // Nonces are assigned across awaits, so overlapping calls (BLE chunks arrive
  // in bursts) must not interleave: every operation runs after the previous one.
  Future<void> _serial = Future.value();

  bool get isEstablished => _send != null;

  Future<T> _ordered<T>(Future<T> Function() operation) {
    final result = _serial.then((_) => operation());
    _serial = result.then((_) {}, onError: (_) {});
    return result;
  }

  /// The initiator (remote) calls this once to get the first bytes to send.
  Future<Uint8List> start() => _ordered(() async {
    final hs = _handshake;
    if (hs == null || !hs.isInitiator) throw SecureChannelException('not the initiator');
    return frame(await hs.writeMessage());
  });

  /// Feeds bytes from the peer; returns what happened, in order.
  Future<List<SecureChannelEvent>> receive(List<int> bytes) => _ordered(() => _receiveNow(bytes));

  /// Encrypts and frames one application message.
  Future<Uint8List> encrypt(List<int> plaintext) => _ordered(() async {
    final tx = _send;
    if (tx == null) throw SecureChannelException('not established');
    return frame(await tx.encrypt(plaintext));
  });

  Future<List<SecureChannelEvent>> _receiveNow(List<int> bytes) async {
    final events = <SecureChannelEvent>[];
    for (final message in _framer.receive(bytes)) {
      final hs = _handshake;
      if (hs != null) {
        await hs.readMessage(message);
        _checkPeer(hs.remoteStatic);
        if (!hs.isComplete) {
          events.add(SendEvent(frame(await hs.writeMessage())));
        }
        if (hs.isComplete) {
          final states = await hs.split();
          _send = states.send;
          _receive = states.receive;
          remoteStaticKey = hs.remoteStatic;
          _handshake = null;
          events.add(EstablishedEvent(remoteStaticKey!));
        }
      } else if (_receive != null) {
        events.add(MessageEvent(await _receive!.decrypt(message)));
      } else {
        throw SecureChannelException('not established');
      }
    }
    return events;
  }

  void _checkPeer(Uint8List? key) {
    if (key == null || _pairing) return;
    if (isHost) {
      if (!_pairedKeys.contains(keyId(key))) throw SecureChannelException('unknown remote');
    } else {
      final pinned = _pinnedHostKey;
      if (pinned != null && !_sameBytes(pinned, key)) throw SecureChannelException('host key mismatch');
    }
  }

  static bool _sameBytes(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Stable string form of a static key, used as the identifier in key sets.
  static String keyId(List<int> key) => base64Url.encode(key);
}

sealed class SecureChannelEvent {}

/// Bytes to write to the peer (handshake replies).
class SendEvent extends SecureChannelEvent {
  SendEvent(this.bytes);
  final Uint8List bytes;
}

/// The handshake finished; the peer's static key is authenticated.
class EstablishedEvent extends SecureChannelEvent {
  EstablishedEvent(this.remoteStaticKey);
  final Uint8List remoteStaticKey;
}

/// A decrypted application message.
class MessageEvent extends SecureChannelEvent {
  MessageEvent(this.plaintext);
  final Uint8List plaintext;
}

class SecureChannelException implements Exception {
  SecureChannelException(this.message);
  final String message;
  @override
  String toString() => 'SecureChannelException: $message';
}
