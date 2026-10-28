import 'dart:async';
import 'dart:math';

import 'package:bluesteer_protocol_dart/bluesteer_protocol_dart.dart';
import 'package:flutter/foundation.dart';
import 'package:universal_ble/universal_ble.dart';

import '../ble/host_link.dart';
import '../platform/link_service.dart';
import 'host_session.dart';
import 'identity.dart';

enum LinkState { connecting, connected, reconnecting, closed }

/// The connection to one paired Mac, kept alive across BLE drops: on a
/// disconnect it reconnects with backoff (SPEC.md §6) and re-runs the
/// handshake, while [envelopes] stays the same stream for the pages.
class HostConnection {
  HostConnection({required this.identity, required this.host});

  final Identity identity;
  final PairedHost host;
  final state = ValueNotifier<LinkState>(LinkState.connecting);
  /// Last connection error, shown while reconnecting.
  String? error;

  final _envelopes = StreamController<Envelope>.broadcast();
  final _reconnected = StreamController<void>.broadcast();
  HostSession? _session;
  BleDevice? _device;
  StreamSubscription<Envelope>? _envelopeSub;
  StreamSubscription<bool>? _linkSub;
  bool _closed = false;

  static const _backoff = [0, 1, 2, 4, 8, 10];

  Stream<Envelope> get envelopes => _envelopes.stream;
  /// Fires after every successful reconnect: pages re-list and re-subscribe.
  Stream<void> get reconnected => _reconnected.stream;
  HostHello? get hello => _session?.hello;
  bool get isConnected => state.value == LinkState.connected;

  /// First connection; throws if the Mac cannot be reached.
  Future<void> connect() async {
    await _establish(await _findAndConnect());
    await LinkService.start(host.name);
  }

  Future<void> send(Envelope e) {
    final s = _session;
    if (s == null || state.value != LinkState.connected) return Future.error(StateError('not connected'));
    return s.send(e);
  }

  Future<Duration> ping() => _session!.ping();

  Future<void> close() async {
    _closed = true;
    state.value = LinkState.closed;
    await LinkService.stop();
    await _teardown();
    await _envelopes.close();
    await _reconnected.close();
  }

  // --- connection management -------------------------------------------------

  /// Connects to each advertising Mac until one has the right INFO id.
  Future<HostLink> _findAndConnect({Duration timeout = const Duration(seconds: 20)}) async {
    await UniversalBle.requestPermissions();
    final found = Completer<HostLink>();
    final tried = <String>{};
    var busy = false;
    final sub = HostLink.scan().listen((d) async {
      if (busy || found.isCompleted || !tried.add(d.deviceId)) return;
      busy = true;
      try {
        final link = await HostLink.connect(d);
        if (link.info.id == host.id && !found.isCompleted) {
          found.complete(link);
        } else {
          await link.close();
        }
      } catch (_) {
      } finally {
        busy = false;
      }
    });
    try {
      return await found.future.timeout(timeout);
    } finally {
      await sub.cancel();
      await UniversalBle.stopScan();
    }
  }

  Future<void> _establish(HostLink link) async {
    final session = await HostSession.establish(link, identity: identity, mode: PairingMode.paired, pinnedHostKey: host.hostKey);
    if (_closed) {
      await session.close();
      return;
    }
    _session = session;
    _device = link.device;
    _envelopeSub = session.envelopes.listen(_envelopes.add, onError: (Object e) => _dropped(e));
    _linkSub = link.connectionState.listen((connected) {
      if (!connected) _dropped(StateError('Bluetooth link lost'));
    });
    error = null;
    state.value = LinkState.connected;
  }

  void _dropped(Object cause) {
    if (_closed || state.value != LinkState.connected) return;
    error = cause.toString();
    state.value = LinkState.reconnecting;
    _reconnectLoop();
  }

  Future<void> _teardown() async {
    await _envelopeSub?.cancel();
    await _linkSub?.cancel();
    _envelopeSub = null;
    _linkSub = null;
    final s = _session;
    _session = null;
    if (s != null) {
      try {
        await s.close();
      } catch (_) {}
    }
  }

  Future<void> _reconnectLoop() async {
    await _teardown();
    for (var attempt = 0; !_closed; attempt++) {
      await Future<void>.delayed(Duration(seconds: _backoff[min(attempt, _backoff.length - 1)]));
      if (_closed) return;
      try {
        HostLink link;
        final device = _device;
        if (device != null && attempt < 3) {
          // The Mac usually keeps its address for a while: reconnect directly first.
          link = await HostLink.connect(device).timeout(const Duration(seconds: 10));
          if (link.info.id != host.id) {
            await link.close();
            throw StateError('a different Mac answered');
          }
        } else {
          // After a longer outage the Mac's address has rotated: scan again.
          link = await _findAndConnect();
        }
        await _establish(link);
        if (!_closed) _reconnected.add(null);
        return;
      } catch (e) {
        error = e.toString();
        if (_device != null && attempt >= 2) _device = null;
      }
    }
  }
}
