import 'dart:async';
import 'dart:math';

import 'package:bluesteer_protocol_dart/bluesteer_protocol_dart.dart';
import 'package:flutter/foundation.dart';

import '../ble/ble_transport.dart';
import '../platform/link_service.dart';
import 'host_session.dart';
import 'identity.dart';
import 'link.dart';

/// `dismissed`: the Mac ended the link on purpose (`HostGoodbye`, "Disconnect all");
/// nothing is retried until [HostConnection.reconnect].
enum LinkState { connecting, connected, reconnecting, dismissed, closed }

/// The connection to one paired Mac, kept alive across BLE drops: on a
/// disconnect it reconnects with backoff (SPEC.md §6) and re-runs the
/// handshake, while [envelopes] stays the same stream for the pages.
///
/// Reconnecting always scans (a few seconds); the Mac's address rotates, so
/// a direct reconnect to a stale address would only waste time. While the
/// radio is off nothing is attempted; when it comes back an attempt starts
/// at once. A generation counter makes a late result from an abandoned
/// attempt harmless: its link is closed.
class HostConnection {
  HostConnection({required this.identity, required this.host, Transport? transport, List<int>? backoffSeconds})
      : _transport = transport ?? BleTransport(),
        _backoff = backoffSeconds ?? defaultBackoffSeconds;

  /// Delay before each reconnect attempt; the last value repeats. Android
  /// refuses more than 5 scan starts in 30 s, which this stays under.
  static const defaultBackoffSeconds = [0, 2, 4, 8, 10];
  /// Scan window for the first connect (the user is waiting) and for a reconnect attempt.
  static const firstConnectTimeout = Duration(seconds: 20);
  static const attemptTimeout = Duration(seconds: 8);
  /// One long attempt instead while the app is backgrounded (iOS; see [Transport.connect]).
  static const backgroundAttemptTimeout = Duration(minutes: 5);

  final Identity identity;
  final PairedHost host;
  final Transport _transport;
  final List<int> _backoff;
  final state = ValueNotifier<LinkState>(LinkState.connecting);
  /// Why we are reconnecting, for the UI.
  String? error;
  /// Set by the app on iOS while it is not in the foreground: reconnect attempts
  /// then use one long window with a pending direct connect.
  bool backgrounded = false;

  final _envelopes = StreamController<Envelope>.broadcast();
  final _reconnected = StreamController<void>.broadcast();
  HostSession? _session;
  StreamSubscription<Envelope>? _envelopeSub;
  StreamSubscription<bool>? _powerSub;
  bool _powered = true;
  Completer<void>? _poweredOn;
  int _generation = 0;
  bool _closed = false;

  Stream<Envelope> get envelopes => _envelopes.stream;
  /// Fires after every successful reconnect: pages re-list and re-subscribe.
  Stream<void> get reconnected => _reconnected.stream;
  HostHello? get hello => _session?.hello;
  bool get isConnected => state.value == LinkState.connected;

  /// First connection; throws if the Mac cannot be reached.
  Future<void> connect() async {
    _powerSub = _transport.powered.listen(_powerChanged);
    final link = await _transport.connect(host.id, timeout: firstConnectTimeout);
    await _establish(link);
    await LinkService.start(host.name);
  }

  Future<void> send(Envelope e) {
    final s = _session;
    if (s == null || state.value != LinkState.connected) return Future.error(StateError('not connected'));
    return s.send(e);
  }

  Future<Duration> ping() => _session?.ping() ?? Future.error(StateError('not connected'));

  Future<void> close() async {
    _closed = true;
    _generation++;
    state.value = LinkState.closed;
    _powerSub?.cancel();
    _poweredOn?.complete();
    _poweredOn = null;
    await LinkService.stop();
    await _teardown();
    await _envelopes.close();
    await _reconnected.close();
  }

  // --- connection management -------------------------------------------------

  Future<void> _establish(Link link) async {
    final HostSession session;
    try {
      session = await HostSession.establish(link, identity: identity, mode: PairingMode.paired, pinnedHostKey: host.hostKey);
    } catch (_) {
      await link.close();
      rethrow;
    }
    if (_closed) {
      await session.close();
      return;
    }
    _session = session;
    _envelopeSub = session.envelopes.listen(_received, onError: (Object e) => _dropped(e));
    error = null;
    state.value = LinkState.connected;
  }

  void _powerChanged(bool on) {
    if (_closed) return;
    _powered = on;
    if (on) {
      debugPrint('[link] radio on');
      _poweredOn?.complete();
      _poweredOn = null;
    } else {
      debugPrint('[link] radio off');
      if (state.value == LinkState.connected) {
        _dropped(StateError('Bluetooth is off'));
      } else {
        error = 'Bluetooth is off';
        _generation++; // an attempt in flight cannot succeed any more
      }
    }
  }

  void _received(Envelope e) {
    if (e.hasHostGoodbye()) {
      _dismissed(e.hostGoodbye.reason);
      return;
    }
    _envelopes.add(e);
  }

  /// The Mac chose "Disconnect all": it stops accepting remotes, so scanning for
  /// it would be pointless. Close the link and wait for the user (SPEC.md §6).
  void _dismissed(String reason) {
    if (_closed || state.value != LinkState.connected) return;
    debugPrint('[link] dismissed: $reason');
    error = reason.isEmpty ? 'Disconnected by ${host.name}' : reason;
    state.value = LinkState.dismissed;
    _generation++;
    _teardown();
  }

  /// After a dismissal, tries again on the user's request.
  void reconnect() {
    if (_closed || state.value != LinkState.dismissed) return;
    state.value = LinkState.reconnecting;
    _reconnectLoop();
  }

  void _dropped(Object cause) {
    if (_closed || state.value != LinkState.connected) return;
    debugPrint('[link] dropped: $cause');
    error = cause.toString();
    state.value = LinkState.reconnecting;
    _generation++;
    _teardown().then((_) => _reconnectLoop());
  }

  Future<void> _teardown() async {
    // Not awaited: a broadcast subscription's cancel future is the shared
    // pre-completed one, which test clocks cannot flush.
    _envelopeSub?.cancel();
    _envelopeSub = null;
    final s = _session;
    _session = null;
    if (s != null) {
      try {
        await s.close();
      } catch (_) {}
    }
  }

  Future<void> _reconnectLoop() async {
    var attempt = 0;
    while (!_closed) {
      if (!_powered) {
        // Parked until the radio is back, then start over at once.
        final back = _poweredOn ??= Completer<void>();
        await back.future;
        attempt = 0;
        continue;
      }
      final delay = _backoff[min(attempt, _backoff.length - 1)];
      if (delay > 0) await Future<void>.delayed(Duration(seconds: delay));
      if (_closed) return;
      if (!_powered) continue;
      final generation = _generation;
      final background = backgrounded;
      debugPrint('[link] attempt $attempt${background ? ' (backgrounded)' : ''}');
      try {
        final link = await _transport.connect(host.id,
            timeout: background ? backgroundAttemptTimeout : attemptTimeout, background: background);
        if (generation != _generation) {
          // Abandoned while connecting (radio off, or close()): not ours any more.
          await link.close();
          if (_closed) return;
          attempt = 0;
          continue;
        }
        await _establish(link);
        if (_closed) return;
        if (generation != _generation) {
          await _teardown();
          attempt = 0;
          continue;
        }
        debugPrint('[link] connected');
        _reconnected.add(null);
        return;
      } catch (e) {
        error = e.toString();
        debugPrint('[link] attempt $attempt failed: $e');
        attempt++;
      }
    }
  }
}
