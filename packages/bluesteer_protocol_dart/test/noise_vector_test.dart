import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bluesteer_protocol_dart/bluesteer_protocol_dart.dart';
import 'package:test/test.dart';

Uint8List hex(String s) =>
    Uint8List.fromList([for (var i = 0; i < s.length; i += 2) int.parse(s.substring(i, i + 2), radix: 16)]);

Future<void> runVector(NoisePattern pattern) async {
  final file = File('../../protocol/testvectors/noise/${pattern.protocolName}.json');
  final v = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
  final messages = (v['messages'] as List).cast<Map<String, dynamic>>();

  final initiator = await NoiseHandshake.create(
    pattern: pattern,
    initiator: true,
    prologue: hex(v['init_prologue'] as String),
    staticKey: await NoiseKeyPair.fromPrivateKey(hex(v['init_static'] as String)),
    psk: v['init_psks'] == null ? null : hex((v['init_psks'] as List).first as String),
    ephemeral: await NoiseKeyPair.fromPrivateKey(hex(v['init_ephemeral'] as String)),
  );
  final responder = await NoiseHandshake.create(
    pattern: pattern,
    initiator: false,
    prologue: hex(v['resp_prologue'] as String),
    staticKey: await NoiseKeyPair.fromPrivateKey(hex(v['resp_static'] as String)),
    psk: v['resp_psks'] == null ? null : hex((v['resp_psks'] as List).first as String),
    ephemeral: await NoiseKeyPair.fromPrivateKey(hex(v['resp_ephemeral'] as String)),
  );

  final handshakeCount = pattern.messages.length;
  for (var i = 0; i < handshakeCount; i++) {
    final payload = hex(messages[i]['payload'] as String);
    final expected = hex(messages[i]['ciphertext'] as String);
    final writer = i.isEven ? initiator : responder;
    final reader = i.isEven ? responder : initiator;
    expect(await writer.writeMessage(payload), expected, reason: '${pattern.name} handshake message $i');
    expect(await reader.readMessage(expected), payload, reason: '${pattern.name} payload $i');
  }
  expect(initiator.isComplete && responder.isComplete, isTrue);
  expect(initiator.handshakeHash, hex(v['handshake_hash'] as String));
  expect(responder.handshakeHash, hex(v['handshake_hash'] as String));

  final i = await initiator.split();
  final r = await responder.split();
  // Senders keep alternating after the handshake, so parity uses the overall index.
  for (var k = handshakeCount; k < messages.length; k++) {
    final payload = hex(messages[k]['payload'] as String);
    final expected = hex(messages[k]['ciphertext'] as String);
    final send = k.isEven ? i.send : r.send;
    final receive = k.isEven ? r.receive : i.receive;
    expect(await send.encrypt(payload), expected, reason: '${pattern.name} transport $k');
    expect(await receive.decrypt(expected), payload);
  }
}

void main() {
  test('Noise_XX vectors', () => runVector(NoisePattern.xx));
  test('Noise_XXpsk3 vectors', () => runVector(NoisePattern.xxpsk3));

  test('wrong PSK fails at the third message', () async {
    final prologue = utf8.encode('bluesteer/1');
    final psk = List.filled(32, 7);
    final bad = List.of(psk)..[0] = 8;
    final i = await NoiseHandshake.create(
        pattern: NoisePattern.xxpsk3, initiator: true, prologue: prologue, staticKey: await NoiseKeyPair.generate(), psk: psk);
    final r = await NoiseHandshake.create(
        pattern: NoisePattern.xxpsk3, initiator: false, prologue: prologue, staticKey: await NoiseKeyPair.generate(), psk: bad);
    await r.readMessage(await i.writeMessage());
    await i.readMessage(await r.writeMessage());
    final third = await i.writeMessage();
    expect(() => r.readMessage(third), throwsA(isA<NoiseException>()));
  });

  test('tampered transport message fails', () async {
    final i = await NoiseHandshake.create(
        pattern: NoisePattern.xx, initiator: true, prologue: const [], staticKey: await NoiseKeyPair.generate());
    final r = await NoiseHandshake.create(
        pattern: NoisePattern.xx, initiator: false, prologue: const [], staticKey: await NoiseKeyPair.generate());
    await r.readMessage(await i.writeMessage());
    await i.readMessage(await r.writeMessage());
    await r.readMessage(await i.writeMessage());
    final c = await (await i.split()).send.encrypt(utf8.encode('hi'));
    c[0] ^= 1;
    final receive = (await r.split()).receive;
    expect(() => receive.decrypt(c), throwsA(isA<NoiseException>()));
  });
}
