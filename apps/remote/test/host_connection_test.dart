import 'package:bluesteer_protocol_dart/bluesteer_protocol_dart.dart';
import 'package:bluesteer_remote/core/host_connection.dart';
import 'package:bluesteer_remote/core/identity.dart';
import 'package:fake_async/fake_async.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

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

  test('backgrounded, a reconnect attempt is one long window with a direct connect', () {
    fakeAsync((async) {
      final link = newLink('mini');
      final (connection, transport) = connected(async, link);
      expect(transport.backgrounds, [false]);

      connection.backgrounded = true;
      link.failNextWrite = true;
      connection.send(Envelope()..ping = (Ping()..nonce = Int64(1))).catchError((Object _) {});
      async.flushMicrotasks();
      expect(connection.state.value, LinkState.reconnecting);
      expect(transport.attempts, hasLength(2));
      expect(transport.backgrounds.last, isTrue);
      expect(transport.timeouts.last, HostConnection.backgroundAttemptTimeout);
      async.elapse(const Duration(seconds: 30));
      expect(transport.attempts, hasLength(2), reason: 'the long window is still open');

      // Back in the foreground the pending window completes like any other attempt.
      connection.backgrounded = false;
      final second = newLink('mini');
      transport.attempts[1].complete(second);
      async.flushMicrotasks();
      expect(connection.state.value, LinkState.connected);

      // The next drop in the foreground uses the short window again.
      second.failNextWrite = true;
      connection.send(Envelope()..ping = (Ping()..nonce = Int64(2))).catchError((Object _) {});
      async.flushMicrotasks();
      expect(transport.backgrounds.last, isFalse);
      expect(transport.timeouts.last, HostConnection.attemptTimeout);
      connection.close();
      async.flushMicrotasks();
    });
  });

  test('HostGoodbye dismisses the link until the user asks to reconnect', () {
    fakeAsync((async) {
      final link = newLink('mini');
      final (connection, transport) = connected(async, link);

      link.sayGoodbye('Disconnected by mini');
      async.flushMicrotasks();
      expect(connection.state.value, LinkState.dismissed);
      expect(connection.error, 'Disconnected by mini');
      expect(link.closed, isTrue);
      async.elapse(const Duration(seconds: 60));
      expect(transport.attempts, hasLength(1), reason: 'nothing is tried after a goodbye');

      connection.reconnect();
      async.flushMicrotasks();
      expect(connection.state.value, LinkState.reconnecting);
      expect(transport.attempts, hasLength(2));
      final second = newLink('mini');
      transport.attempts[1].complete(second);
      async.flushMicrotasks();
      expect(connection.state.value, LinkState.connected);
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
