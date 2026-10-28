// Remote side of the cross-language SecureChannel check. See tools/Sources/channel-probe.
//
//   dart run tool/probe_remote.dart <port> <psk-hex>
import 'dart:io';
import 'dart:typed_data';

import 'package:bluesteer_protocol_dart/bluesteer_protocol_dart.dart';
import 'package:fixnum/fixnum.dart';

Future<void> main(List<String> args) async {
  final port = int.parse(args[0]);
  final psk = [for (var i = 0; i < args[1].length; i += 2) int.parse(args[1].substring(i, i + 2), radix: 16)];
  final channel = await SecureChannel.remote(staticKey: await NoiseKeyPair.generate(), pairingPsk: psk);
  final socket = await Socket.connect('127.0.0.1', port);
  socket.add(await channel.start());
  const nonce = 0xC0FFEE;
  await for (final chunk in socket) {
    for (final event in await channel.receive(chunk)) {
      switch (event) {
        case SendEvent(:final bytes):
          socket.add(bytes);
        case EstablishedEvent(:final remoteStaticKey):
          stdout.writeln('established with host key ${SecureChannel.keyId(remoteStaticKey)}');
          final ping = Envelope()..ping = (Ping()..nonce = Int64(nonce));
          socket.add(await channel.encrypt(ping.writeToBuffer()));
        case MessageEvent(:final plaintext):
          final envelope = Envelope.fromBuffer(Uint8List.fromList(plaintext));
          if (!envelope.hasPong() || envelope.pong.nonce.toInt() != nonce) {
            stderr.writeln('unexpected reply: $envelope');
            exit(1);
          }
          stdout.writeln('pong ok');
          await socket.close();
          exit(0);
      }
    }
  }
  stderr.writeln('connection closed before pong');
  exit(1);
}
