import 'dart:async';
import 'dart:typed_data';

import 'package:bluesteer_protocol_dart/bluesteer_protocol_dart.dart';
import 'package:bluesteer_remote/core/host_connection.dart';
import 'package:bluesteer_remote/core/identity.dart';
import 'package:bluesteer_remote/core/link.dart';
import 'package:fake_async/fake_async.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';

/// An in-memory link whose far end is a Mac: a `SecureChannel.host` that
/// answers `RemoteHello` with `HostHello` and pings with pongs.
class FakeLink implements Link {
  FakeLink(this.name, {required this.hostKey, required this.pairedKeys});
  final String name;
  final NoiseKeyPair hostKey;
  final Set<String> pairedKeys;
  final _toRemote = StreamController<Uint8List>();
  SecureChannel? _mac;
  bool _first = true;
  bool closed = false;
  bool failNextWrite = false;
  int writes = 0;

  @override
  Stream<Uint8List> get incoming => _toRemote.stream;

  @override
  Future<void> write(List<int> bytes) async {
    writes++;
    if (closed) throw StateError('link closed');
    if (failNextWrite) {
      failNextWrite = false;
      await close();
      throw StateError('write failed');
    }
    if (_first) {
      _first = false;
      bytes = bytes.sublist(1); // the selector byte (SPEC.md §2.0)
      _mac = await SecureChannel.host(staticKey: hostKey, pairedKeys: pairedKeys);
    }
    final mac = _mac!;
    for (final event in await mac.receive(bytes)) {
      switch (event) {
        case SendEvent(:final bytes):
          _toRemote.add(bytes);
        case EstablishedEvent():
          break;
        case MessageEvent(:final plaintext):
          final e = Envelope.fromBuffer(plaintext);
          if (e.hasRemoteHello()) {
            _toRemote.add(await mac.encrypt(
                (Envelope()..hostHello = (HostHello()..hostName = name..protocolVersion = protocolVersion)).writeToBuffer()));
          }
          if (e.hasPing()) {
            _toRemote.add(await mac.encrypt((Envelope()..pong = (Pong()..nonce = e.ping.nonce)).writeToBuffer()));
          }
      }
    }
  }

  @override
  Future<void> close() async {
    if (closed) return;
    closed = true;
    _toRemote.close(); // not awaited: it completes only once a listener saw "done"
  }
}

/// Connect attempts are completed by the test; `powered` is driven by [power].
class FakeTransport implements Transport {
  FakeTransport({this.initiallyOn = true});
  final bool initiallyOn;
  final power = StreamController<bool>.broadcast();
  final attempts = <Completer<Link>>[];

  @override
  Stream<bool> get powered async* {
    yield initiallyOn;
    yield* power.stream;
  }

  /// Like the real transport, a link that turns up after the window is closed.
  @override
  Future<Link> connect(String hostId, {required Duration timeout}) {
    final c = Completer<Link>();
    attempts.add(c);
    return c.future.timeout(timeout, onTimeout: () {
      c.future.then((link) => link.close());
      throw TimeoutException('scan window over', timeout);
    });
  }
}

void main() {
  late NoiseKeyPair hostKey;
  late Identity identity;
  late PairedHost host;

  setUpAll(() async {
    hostKey = await NoiseKeyPair.generate();
    identity = Identity.inMemory(keyPair: await NoiseKeyPair.generate());
    host = PairedHost(id: 'host-1', name: 'mini', hostKey: hostKey.publicKey);
  });

  FakeLink newLink(String name) => FakeLink(name, hostKey: hostKey, pairedKeys: {SecureChannel.keyId(identity.keyPair.publicKey)});

  /// A connection that is connected over [link] when this returns.
  (HostConnection, FakeTransport) connected(FakeAsync async, FakeLink link, {bool radioOn = true}) {
    final transport = FakeTransport(initiallyOn: radioOn);
    final connection = HostConnection(identity: identity, host: host, transport: transport);
    connection.connect();
    async.flushMicrotasks();
    transport.attempts.single.complete(link);
    async.flushMicrotasks();
    expect(connection.state.value, LinkState.connected);
    expect(connection.hello?.hostName, 'mini');
    return (connection, transport);
  }

  test('radio off parks the connection; radio on reconnects at once', () {
    fakeAsync((async) {
      final link = newLink('mini');
      final (connection, transport) = connected(async, link);
      var reconnects = 0;
      connection.reconnected.listen((_) => reconnects++);

      transport.power.add(false);
      async.flushMicrotasks();
      expect(connection.state.value, LinkState.reconnecting);
      expect(connection.error, contains('Bluetooth'));
      expect(link.closed, isTrue);
      async.elapse(const Duration(seconds: 60));
      expect(transport.attempts, hasLength(1), reason: 'nothing is tried while the radio is off');

      transport.power.add(true);
      async.flushMicrotasks();
      expect(transport.attempts, hasLength(2), reason: 'an attempt starts as soon as the radio is back');
      final second = newLink('mini');
      transport.attempts[1].complete(second);
      async.flushMicrotasks();
      expect(connection.state.value, LinkState.connected);
      expect(reconnects, 1);
      connection.close();
      async.flushMicrotasks();
    });
  });

  test('a failed write drops the link and reconnects', () {
    fakeAsync((async) {
      final link = newLink('mini');
      final (connection, transport) = connected(async, link);

      link.failNextWrite = true;
      Object? sendError;
      connection.send(Envelope()..ping = (Ping()..nonce = Int64(1))).catchError((Object e) => sendError = e);
      async.flushMicrotasks();
      expect(sendError, isNotNull);
      expect(connection.state.value, LinkState.reconnecting);
      expect(transport.attempts, hasLength(2), reason: 'attempt 0 has no delay');

      final second = newLink('mini');
      transport.attempts[1].complete(second);
      async.flushMicrotasks();
      expect(connection.state.value, LinkState.connected);
      connection.send(Envelope()..ping = (Ping()..nonce = Int64(2)));
      async.flushMicrotasks();
      expect(second.writes, greaterThan(2), reason: 'traffic goes to the new link');
      connection.close();
      async.flushMicrotasks();
    });
  });

  test('a late result from an abandoned attempt is closed', () {
    fakeAsync((async) {
      final link = newLink('mini');
      final (connection, transport) = connected(async, link);
      var reconnects = 0;
      connection.reconnected.listen((_) => reconnects++);

      link.failNextWrite = true;
      connection.send(Envelope()..ping = (Ping()..nonce = Int64(1))).catchError((_) {});
      async.flushMicrotasks();
      expect(transport.attempts, hasLength(2)); // attempt in flight
      transport.power.add(false); // abandons it
      transport.power.add(true);
      async.flushMicrotasks();
      final late = newLink('mini');
      transport.attempts[1].complete(late);
      async.flushMicrotasks();
      expect(late.closed, isTrue, reason: 'the abandoned attempt\'s link is closed');
      expect(transport.attempts, hasLength(3), reason: 'a fresh attempt follows');
      final fresh = newLink('mini');
      transport.attempts[2].complete(fresh);
      async.flushMicrotasks();
      expect(connection.state.value, LinkState.connected);
      expect(reconnects, 1);
      connection.close();
      async.flushMicrotasks();
    });
  });

  test('attempts follow the backoff schedule', () {
    fakeAsync((async) {
      final link = newLink('mini');
      final (connection, transport) = connected(async, link);
      link.failNextWrite = true;
      connection.send(Envelope()..ping = (Ping()..nonce = Int64(1))).catchError((_) {});
      async.flushMicrotasks();

      // Each attempt fails at once; the next starts after 0, 2, 4, 8, 10, 10 s.
      for (final delay in [2, 4, 8, 10, 10]) {
        final n = transport.attempts.length;
        transport.attempts.last.completeError(StateError('no Mac in range'));
        async.flushMicrotasks();
        async.elapse(Duration(seconds: delay) - const Duration(milliseconds: 1));
        expect(transport.attempts, hasLength(n), reason: 'waits $delay s');
        async.elapse(const Duration(milliseconds: 1));
        expect(transport.attempts, hasLength(n + 1));
      }
      connection.close();
      async.flushMicrotasks();
    });
  });

  test('close() during a reconnect stops everything', () {
    fakeAsync((async) {
      final link = newLink('mini');
      final (connection, transport) = connected(async, link);
      link.failNextWrite = true;
      connection.send(Envelope()..ping = (Ping()..nonce = Int64(1))).catchError((_) {});
      async.flushMicrotasks();
      expect(transport.attempts, hasLength(2));

      connection.close();
      async.flushMicrotasks();
      expect(connection.state.value, LinkState.closed);
      final late = newLink('mini');
      transport.attempts[1].complete(late);
      async.flushMicrotasks();
      expect(late.closed, isTrue, reason: 'the attempt finished after close(): its link is closed');
      async.elapse(const Duration(seconds: 60));
      expect(transport.attempts, hasLength(2), reason: 'no attempts after close()');
    });
  });
}
