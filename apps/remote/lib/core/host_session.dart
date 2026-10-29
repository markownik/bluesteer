import 'dart:async';

import 'package:bluesteer_protocol_dart/bluesteer_protocol_dart.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter/foundation.dart';

import 'identity.dart';
import 'link.dart';

/// The Mac speaks another protocol version (SPEC.md §7): this app cannot talk to it.
class ProtocolMismatchException implements Exception {
  ProtocolMismatchException(this.hostVersion);
  final int hostVersion;
  @override
  String toString() => hostVersion > protocolVersion
      ? 'This Mac runs a newer BlueSteer (protocol $hostVersion); update this app.'
      : 'This Mac runs an older BlueSteer (protocol $hostVersion); update BlueSteer on the Mac.';
}

/// Handshake selector byte (SPEC.md §2.0).
enum PairingMode {
  psk(0x01),
  paired(0x02),
  code(0x03);

  const PairingMode(this.selector);
  final int selector;
}

/// A pairing by code (SPEC.md §2.1b) waiting for the user to compare codes.
class PendingPairing {
  PendingPairing._(this.session, this.code);
  final HostSession session;
  final String code;

  /// The user saw the same code on the Mac. Completes with the session once
  /// the Mac's user confirmed too; throws if the Mac rejected.
  Future<HostSession> confirm() async {
    await session.send(Envelope()..pairConfirm = (PairConfirm()..cmdId = Int64(1)));
    await session._hello.future.timeout(const Duration(seconds: 120));
    return session;
  }
}

/// An authenticated, encrypted session with one host over a [Link].
class HostSession {
  HostSession._(this.link, this._channel);

  /// Three Noise round trips at ~50 ms each need well under a second; this
  /// also bounds how long a link the host silently dropped keeps us waiting.
  static const handshakeTimeout = Duration(seconds: 8);

  final Link link;
  final SecureChannel _channel;
  final _envelopes = StreamController<Envelope>.broadcast();
  final _pendingPongs = <int, Completer<void>>{};
  final _hello = Completer<HostHello>();
  HostHello? hello;

  Stream<Envelope> get envelopes => _envelopes.stream;
  Uint8List get hostKey => _channel.remoteStaticKey!;

  /// Runs the handshake and the hellos. For [PairingMode.psk] pass the PSK from
  /// the QR code; for [PairingMode.paired] the pinned host key. Returns once the
  /// host sent its `HostHello`. Use [pairByCode] for [PairingMode.code].
  static Future<HostSession> establish(
    Link link, {
    required Identity identity,
    required PairingMode mode,
    List<int>? pairingPsk,
    List<int>? pinnedHostKey,
    Duration timeout = handshakeTimeout,
  }) async {
    final session = await _handshake(link, identity: identity, mode: mode, pairingPsk: pairingPsk, pinnedHostKey: pinnedHostKey, timeout: timeout);
    await session._hello.future.timeout(timeout);
    return session;
  }

  /// Handshake for pairing by code; the caller shows [PendingPairing.code].
  static Future<PendingPairing> pairByCode(Link link, {required Identity identity}) async {
    final session = await _handshake(link, identity: identity, mode: PairingMode.code, timeout: handshakeTimeout);
    return PendingPairing._(session, await SecureChannel.pairingCode(session._channel.handshakeHash!));
  }

  static Future<HostSession> _handshake(
    Link link, {
    required Identity identity,
    required PairingMode mode,
    List<int>? pairingPsk,
    List<int>? pinnedHostKey,
    required Duration timeout,
  }) async {
    final channel = await SecureChannel.remote(staticKey: identity.keyPair, pairingPsk: pairingPsk, pinnedHostKey: pinnedHostKey);
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
        session._fail(e, st);
      }
    }, onDone: () {
      if (!established.isCompleted) established.completeError(StateError('link closed during handshake'));
      session._fail(StateError('link closed'), StackTrace.current);
      session._envelopes.close();
    });
    await link.write([mode.selector, ...await channel.start()]);
    debugPrint('[link] handshake sent');
    try {
      await established.future.timeout(timeout);
    } catch (_) {
      await sub.cancel();
      rethrow;
    }
    await session.send(Envelope()
      ..remoteHello = (RemoteHello()
        ..protocolVersion = protocolVersion
        ..deviceName = identity.deviceName
        ..appVersion = appVersion));
    return session;
  }

  /// A broken channel fails whoever is waiting, instead of leaving them to time out.
  void _fail(Object error, StackTrace st) {
    for (final pong in _pendingPongs.values) {
      if (!pong.isCompleted) pong.completeError(error, st);
    }
    _pendingPongs.clear();
    if (!_hello.isCompleted) _hello.completeError(error, st);
    if (!_envelopes.isClosed) _envelopes.addError(error, st);
  }

  void _handle(Envelope e) {
    if (e.hasHostHello()) {
      if (e.hostHello.protocolVersion != protocolVersion) {
        _fail(ProtocolMismatchException(e.hostHello.protocolVersion), StackTrace.current);
        return;
      }
      hello = e.hostHello;
      if (!_hello.isCompleted) _hello.complete(e.hostHello);
    }
    if (e.hasAck() && !e.ack.ok && !_hello.isCompleted) {
      // Only pairing by code gets an Ack before HostHello: the Mac rejected us.
      _hello.completeError(StateError(e.ack.error.isEmpty ? 'rejected by the Mac' : e.ack.error));
    }
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
