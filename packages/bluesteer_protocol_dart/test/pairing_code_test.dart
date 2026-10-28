import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bluesteer_protocol_dart/bluesteer_protocol_dart.dart';
import 'package:test/test.dart';

Uint8List hex(String s) =>
    Uint8List.fromList([for (var i = 0; i < s.length; i += 2) int.parse(s.substring(i, i + 2), radix: 16)]);

void main() {
  test('pairing codes match the shared vectors', () async {
    final v = jsonDecode(await File('../../protocol/testvectors/pairing-code.json').readAsString()) as Map<String, dynamic>;
    final vectors = (v['vectors'] as List).cast<Map<String, dynamic>>();
    expect(vectors, isNotEmpty);
    for (final e in vectors) {
      expect(await SecureChannel.pairingCode(hex(e['handshake_hash'] as String)), e['code']);
    }
  });

  test('both ends derive the same code; unknown remote accepted when asked', () async {
    final hostKey = await NoiseKeyPair.generate();
    final remoteKey = await NoiseKeyPair.generate();
    final host = await SecureChannel.host(staticKey: hostKey, pairedKeys: {}, acceptUnknownRemote: true);
    final remote = await SecureChannel.remote(staticKey: remoteKey);
    var toHost = await remote.start();
    var toRemote = <int>[];
    for (var i = 0; i < 3; i++) {
      for (final e in await host.receive(toHost)) {
        if (e is SendEvent) toRemote.addAll(e.bytes);
      }
      toHost = Uint8List(0);
      for (final e in await remote.receive(toRemote)) {
        if (e is SendEvent) toHost = e.bytes;
      }
      toRemote = [];
    }
    expect(host.isEstablished && remote.isEstablished, isTrue);
    expect(host.handshakeHash, remote.handshakeHash);
    final code = await SecureChannel.pairingCode(host.handshakeHash!);
    expect(code.length, 6);
    expect(code, await SecureChannel.pairingCode(remote.handshakeHash!));
  });
}
