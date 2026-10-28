import 'dart:convert';
import 'dart:typed_data';

import 'package:bluesteer_protocol_dart/bluesteer_protocol_dart.dart';
import 'package:test/test.dart';

Future<List<SecureChannelEvent>> deliver(List<int> data, SecureChannel to, int chunk) async {
  final events = <SecureChannelEvent>[];
  for (var i = 0; i < data.length; i += chunk) {
    events.addAll(await to.receive(data.sublist(i, i + chunk > data.length ? data.length : i + chunk)));
  }
  return events;
}

/// Runs a full handshake; returns (remote key seen by host, host key seen by remote).
Future<(Uint8List, Uint8List)> connect(SecureChannel remote, SecureChannel host, {int chunk = 7}) async {
  var toHost = await remote.start();
  Uint8List? remoteKey, hostKey;
  for (var round = 0; round < 4 && (remoteKey == null || hostKey == null); round++) {
    final toRemote = BytesBuilder();
    for (final e in await deliver(toHost, host, chunk)) {
      if (e is SendEvent) toRemote.add(e.bytes);
      if (e is EstablishedEvent) remoteKey = e.remoteStaticKey;
    }
    final back = BytesBuilder();
    for (final e in await deliver(toRemote.takeBytes(), remote, chunk)) {
      if (e is SendEvent) back.add(e.bytes);
      if (e is EstablishedEvent) hostKey = e.remoteStaticKey;
    }
    toHost = back.takeBytes();
  }
  return (remoteKey!, hostKey!);
}

void main() {
  test('pairing then reconnect with pinned keys', () async {
    final hostKey = await NoiseKeyPair.generate();
    final remoteKey = await NoiseKeyPair.generate();
    final psk = List<int>.generate(32, (i) => i * 7 & 0xff);

    final host = await SecureChannel.host(staticKey: hostKey, pairedKeys: {}, pairingPsk: psk);
    final remote = await SecureChannel.remote(staticKey: remoteKey, pairingPsk: psk);
    final (seenRemote, seenHost) = await connect(remote, host);
    expect(seenRemote, remoteKey.publicKey);
    expect(seenHost, hostKey.publicKey);

    final c1 = await remote.encrypt(utf8.encode('ping'));
    final got = await deliver(c1, host, 3);
    expect((got.single as MessageEvent).plaintext, utf8.encode('ping'));
    final c2 = await host.encrypt(utf8.encode('pong'));
    expect(((await deliver(c2, remote, 5)).single as MessageEvent).plaintext, utf8.encode('pong'));

    final host2 = await SecureChannel.host(staticKey: hostKey, pairedKeys: {SecureChannel.keyId(remoteKey.publicKey)});
    final remote2 = await SecureChannel.remote(staticKey: remoteKey, pinnedHostKey: hostKey.publicKey);
    await connect(remote2, host2, chunk: 64);
    expect(host2.isEstablished && remote2.isEstablished, isTrue);
  });

  test('unknown remote is rejected', () async {
    final host = await SecureChannel.host(
        staticKey: await NoiseKeyPair.generate(), pairedKeys: {SecureChannel.keyId((await NoiseKeyPair.generate()).publicKey)});
    final remote = await SecureChannel.remote(staticKey: await NoiseKeyPair.generate());
    expect(() => connect(remote, host), throwsA(isA<SecureChannelException>()));
  });

  test('host key mismatch is rejected', () async {
    final host = await SecureChannel.host(staticKey: await NoiseKeyPair.generate(), pairedKeys: {});
    final remote = await SecureChannel.remote(
        staticKey: await NoiseKeyPair.generate(), pinnedHostKey: (await NoiseKeyPair.generate()).publicKey);
    expect(() => connect(remote, host), throwsA(isA<SecureChannelException>()));
  });

  test('wrong pairing PSK fails', () async {
    final host = await SecureChannel.host(
        staticKey: await NoiseKeyPair.generate(), pairedKeys: {}, pairingPsk: List.filled(32, 1));
    final remote = await SecureChannel.remote(staticKey: await NoiseKeyPair.generate(), pairingPsk: List.filled(32, 2));
    expect(() => connect(remote, host), throwsA(isA<Exception>()));
  });
}
