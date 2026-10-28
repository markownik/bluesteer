// Noise Protocol Framework (revision 34) for the two patterns BlueSteer uses:
// Noise_XX_25519_ChaChaPoly_SHA256 and Noise_XXpsk3_25519_ChaChaPoly_SHA256
// (SPEC.md §2). Mirrors the Swift implementation; verified against
// protocol/testvectors/noise.
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

enum NoisePattern {
  xx('Noise_XX_25519_ChaChaPoly_SHA256', [
    ['e'],
    ['e', 'ee', 's', 'es'],
    ['s', 'se'],
  ]),
  xxpsk3('Noise_XXpsk3_25519_ChaChaPoly_SHA256', [
    ['e'],
    ['e', 'ee', 's', 'es'],
    ['s', 'se', 'psk'],
  ]);

  const NoisePattern(this.protocolName, this.messages);
  final String protocolName;
  final List<List<String>> messages;
  bool get usesPsk => this == NoisePattern.xxpsk3;
}

class NoiseException implements Exception {
  NoiseException(this.message);
  final String message;
  @override
  String toString() => 'NoiseException: $message';
}

final _x25519 = X25519();
final _aead = Chacha20.poly1305Aead();
final _hmacSha256 = Hmac.sha256();
final _sha256 = Sha256();

/// A Curve25519 static or ephemeral key pair.
class NoiseKeyPair {
  NoiseKeyPair._(this._keyPair, this.publicKey);
  final SimpleKeyPair _keyPair;
  final Uint8List publicKey;

  static Future<NoiseKeyPair> generate() async {
    final kp = await _x25519.newKeyPair();
    return NoiseKeyPair._(kp, Uint8List.fromList((await kp.extractPublicKey()).bytes));
  }

  static Future<NoiseKeyPair> fromPrivateKey(List<int> privateKey) async {
    final kp = await _x25519.newKeyPairFromSeed(privateKey);
    return NoiseKeyPair._(kp, Uint8List.fromList((await kp.extractPublicKey()).bytes));
  }

  Future<List<int>> privateKeyBytes() async => (await _keyPair.extract()).bytes;

  Future<Uint8List> dh(List<int> remotePublic) async {
    final shared = await _x25519.sharedSecretKey(
      keyPair: _keyPair,
      remotePublicKey: SimplePublicKey(remotePublic, type: KeyPairType.x25519),
    );
    return Uint8List.fromList(await shared.extractBytes());
  }
}

/// AEAD state for one direction of a Noise session.
class NoiseCipherState {
  NoiseCipherState([List<int>? key]) : _key = key == null ? null : SecretKey(key);
  final SecretKey? _key;
  int _nonce = 0;

  bool get hasKey => _key != null;

  Uint8List _nonceBytes() {
    final n = Uint8List(12);
    ByteData.sublistView(n).setUint64(4, _nonce, Endian.little);
    return n;
  }

  Future<Uint8List> encrypt(List<int> plaintext, {List<int> ad = const []}) async {
    final key = _key;
    if (key == null) return Uint8List.fromList(plaintext);
    if (_nonce == -1) throw NoiseException('nonce exhausted');
    final box = await _aead.encrypt(plaintext, secretKey: key, nonce: _nonceBytes(), aad: ad);
    _nonce++;
    return Uint8List.fromList([...box.cipherText, ...box.mac.bytes]);
  }

  Future<Uint8List> decrypt(List<int> ciphertext, {List<int> ad = const []}) async {
    final key = _key;
    if (key == null) return Uint8List.fromList(ciphertext);
    if (ciphertext.length < 16) throw NoiseException('message too short');
    final box = SecretBox(
      ciphertext.sublist(0, ciphertext.length - 16),
      nonce: _nonceBytes(),
      mac: Mac(ciphertext.sublist(ciphertext.length - 16)),
    );
    final List<int> plain;
    try {
      plain = await _aead.decrypt(box, secretKey: key, aad: ad);
    } on SecretBoxAuthenticationError {
      throw NoiseException('decryption failed');
    }
    _nonce++;
    return Uint8List.fromList(plain);
  }
}

class _SymmetricState {
  _SymmetricState._(this.hash) : chainingKey = hash;

  static Future<_SymmetricState> create(String protocolName) async {
    final name = protocolName.codeUnits;
    final h = name.length <= 32
        ? (Uint8List(32)..setRange(0, name.length, name))
        : Uint8List.fromList((await _sha256.hash(name)).bytes);
    return _SymmetricState._(h);
  }

  Uint8List chainingKey;
  Uint8List hash;
  NoiseCipherState cipher = NoiseCipherState();

  static Future<Uint8List> _hmac(List<int> key, List<int> data) async =>
      Uint8List.fromList((await _hmacSha256.calculateMac(data, secretKey: SecretKey(key))).bytes);

  static Future<List<Uint8List>> _hkdf(List<int> ck, List<int> input, int outputs) async {
    final temp = await _hmac(ck, input);
    final out = <Uint8List>[await _hmac(temp, [1])];
    for (var i = 2; i <= outputs; i++) {
      out.add(await _hmac(temp, [...out[i - 2], i]));
    }
    return out;
  }

  Future<void> mixKey(List<int> input) async {
    final k = await _hkdf(chainingKey, input, 2);
    chainingKey = k[0];
    cipher = NoiseCipherState(k[1]);
  }

  Future<void> mixHash(List<int> data) async {
    hash = Uint8List.fromList((await _sha256.hash([...hash, ...data])).bytes);
  }

  Future<void> mixKeyAndHash(List<int> input) async {
    final k = await _hkdf(chainingKey, input, 3);
    chainingKey = k[0];
    await mixHash(k[1]);
    cipher = NoiseCipherState(k[2]);
  }

  Future<Uint8List> encryptAndHash(List<int> plaintext) async {
    final c = await cipher.encrypt(plaintext, ad: hash);
    await mixHash(c);
    return c;
  }

  Future<Uint8List> decryptAndHash(List<int> ciphertext) async {
    final p = await cipher.decrypt(ciphertext, ad: hash);
    await mixHash(ciphertext);
    return p;
  }

  Future<(NoiseCipherState, NoiseCipherState)> split() async {
    final k = await _hkdf(chainingKey, const [], 2);
    return (NoiseCipherState(k[0]), NoiseCipherState(k[1]));
  }
}

/// Drives one Noise handshake. Call [writeMessage]/[readMessage] alternately
/// starting with the initiator; when [isComplete], call [split].
class NoiseHandshake {
  NoiseHandshake._(this.pattern, this.isInitiator, this._s, this._e, this._psk, this._symmetric)
      : _remaining = List.of(pattern.messages),
        _myTurn = isInitiator;

  /// [ephemeral] is only for tests; a fresh key is generated otherwise.
  static Future<NoiseHandshake> create({
    required NoisePattern pattern,
    required bool initiator,
    required List<int> prologue,
    required NoiseKeyPair staticKey,
    List<int>? psk,
    NoiseKeyPair? ephemeral,
  }) async {
    if (pattern.usesPsk && (psk == null || psk.length != 32)) throw NoiseException('missing psk');
    final sym = await _SymmetricState.create(pattern.protocolName);
    await sym.mixHash(prologue);
    return NoiseHandshake._(pattern, initiator, staticKey, ephemeral, psk, sym);
  }

  final NoisePattern pattern;
  final bool isInitiator;
  final _SymmetricState _symmetric;
  final NoiseKeyPair _s;
  NoiseKeyPair? _e;
  final List<int>? _psk;
  final List<List<String>> _remaining;
  bool _myTurn;
  Uint8List? remoteStatic;
  Uint8List? _remoteEphemeral;

  bool get isComplete => _remaining.isEmpty;
  Uint8List get handshakeHash => _symmetric.hash;

  Future<Uint8List> _dhToken(String token) async {
    switch (token) {
      case 'ee':
        return _e!.dh(_remoteEphemeral!);
      case 'es':
        return isInitiator ? _e!.dh(remoteStatic!) : _s.dh(_remoteEphemeral!);
      case 'se':
        return isInitiator ? _s.dh(_remoteEphemeral!) : _e!.dh(remoteStatic!);
      case 'ss':
        return _s.dh(remoteStatic!);
      default:
        throw StateError('unknown token $token');
    }
  }

  Future<Uint8List> writeMessage([List<int> payload = const []]) async {
    if (isComplete) throw NoiseException('handshake complete');
    if (!_myTurn) throw NoiseException('not your turn');
    final out = BytesBuilder(copy: false);
    for (final token in _remaining.removeAt(0)) {
      switch (token) {
        case 'e':
          _e ??= await NoiseKeyPair.generate();
          out.add(_e!.publicKey);
          await _symmetric.mixHash(_e!.publicKey);
          if (pattern.usesPsk) await _symmetric.mixKey(_e!.publicKey);
        case 's':
          out.add(await _symmetric.encryptAndHash(_s.publicKey));
        case 'psk':
          await _symmetric.mixKeyAndHash(_psk!);
        default:
          await _symmetric.mixKey(await _dhToken(token));
      }
    }
    out.add(await _symmetric.encryptAndHash(payload));
    if (out.length > 65535) throw NoiseException('message too long');
    _myTurn = false;
    return out.takeBytes();
  }

  Future<Uint8List> readMessage(List<int> message) async {
    if (isComplete) throw NoiseException('handshake complete');
    if (_myTurn) throw NoiseException('not your turn');
    var cursor = 0;
    Uint8List take(int n) {
      if (message.length - cursor < n) throw NoiseException('message too short');
      final chunk = Uint8List.fromList(message.sublist(cursor, cursor + n));
      cursor += n;
      return chunk;
    }

    for (final token in _remaining.removeAt(0)) {
      switch (token) {
        case 'e':
          final re = take(32);
          _remoteEphemeral = re;
          await _symmetric.mixHash(re);
          if (pattern.usesPsk) await _symmetric.mixKey(re);
        case 's':
          remoteStatic = await _symmetric.decryptAndHash(take(_symmetric.cipher.hasKey ? 48 : 32));
        case 'psk':
          await _symmetric.mixKeyAndHash(_psk!);
        default:
          await _symmetric.mixKey(await _dhToken(token));
      }
    }
    final payload = await _symmetric.decryptAndHash(message.sublist(cursor));
    _myTurn = true;
    return payload;
  }

  /// Transport cipher states: `send` encrypts our messages, `receive` decrypts the peer's.
  Future<({NoiseCipherState send, NoiseCipherState receive})> split() async {
    if (!isComplete) throw NoiseException('handshake not complete');
    final (c1, c2) = await _symmetric.split();
    return isInitiator ? (send: c1, receive: c2) : (send: c2, receive: c1);
  }
}
