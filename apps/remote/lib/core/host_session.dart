import 'dart:async';
import 'dart:typed_data';

import 'package:bluesteer_protocol_dart/bluesteer_protocol_dart.dart';
import 'package:fixnum/fixnum.dart';

import '../ble/host_link.dart';

/// An authenticated, encrypted session with one host over a [HostLink].
class HostSession {
  HostSession._(this.link, this._channel);

  final HostLink link;
  final SecureChannel _channel;
  final _envelopes = StreamController<Envelope>.broadcast();
  final _pendingPongs = <int, Completer<void>>{};
  HostHello? hello;

  Stream<Envelope> get envelopes => _envelopes.stream;
  Uint8List get hostKey => _channel.remoteStaticKey!;

  /// Runs the handshake. Pass [pairingPsk] from the QR code when pairing,
  /// otherwise [pinnedHostKey] from a previous pairing.
  static Future<HostSession> establish(
    HostLink link, {
    required NoiseKeyPair identity,
    List<int>? pairingPsk,
    List<int>? pinnedHostKey,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final channel = await SecureChannel.remote(staticKey: identity, pairingPsk: pairingPsk, pinnedHostKey: pinnedHostKey);
    final session = HostSession._(link, channel);
    final established = Completer<void>();
    late final StreamSubscription<Uint8List> sub;
    sub = link.incoming.listen((chunk) async {
      try {
        for (final event in await channel.receive(chunk)) {
          switch (event) {
            case SendEvent(:final bytes):
              await link.write(bytes);
            case EstablishedEvent():
              if (!established.isCompleted) established.complete();
            case MessageEvent(:final plaintext):
              session._handle(Envelope.fromBuffer(plaintext));
          }
        }
      } catch (e, st) {
        if (!established.isCompleted) established.completeError(e, st);
        session._envelopes.addError(e, st);
      }
    }, onDone: () {
      if (!established.isCompleted) established.completeError(StateError('link closed during handshake'));
      session._envelopes.close();
    });
    await link.write(await channel.start());
    try {
      await established.future.timeout(timeout);
    } catch (_) {
      await sub.cancel();
      rethrow;
    }
    return session;
  }

  void _handle(Envelope e) {
    if (e.hasHostHello()) hello = e.hostHello;
    if (e.hasPong()) _pendingPongs.remove(e.pong.nonce.toInt())?.complete();
    _envelopes.add(e);
  }

  Future<void> send(Envelope e) async => link.write(await _channel.encrypt(e.writeToBuffer()));

  /// Round-trip time of one Ping.
  Future<Duration> ping() async {
    final nonce = DateTime.now().microsecondsSinceEpoch & 0x7fffffff;
    final completer = Completer<void>();
    _pendingPongs[nonce] = completer;
    final started = DateTime.now();
    await send(Envelope()..ping = (Ping()..nonce = Int64(nonce)));
    await completer.future.timeout(const Duration(seconds: 5));
    return DateTime.now().difference(started);
  }

  Future<void> close() => link.close();
}
