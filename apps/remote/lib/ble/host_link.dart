import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:universal_ble/universal_ble.dart';

import '../core/link.dart';

/// GATT details from SPEC.md §1.1.
const bluesteerServiceUuid = '7b5e5a6e-0001-4b1e-9c0e-5a2d2e1f0001';
const _txUuid = '7b5e5a6e-0002-4b1e-9c0e-5a2d2e1f0001';
const _rxUuid = '7b5e5a6e-0003-4b1e-9c0e-5a2d2e1f0001';
const _infoUuid = '7b5e5a6e-0004-4b1e-9c0e-5a2d2e1f0001';
const _statusUuid = '7b5e5a6e-0005-4b1e-9c0e-5a2d2e1f0001';

/// What a host advertises in its INFO characteristic.
class HostInfo {
  HostInfo(this.protocolVersion, this.instanceId, this.name);
  final int protocolVersion;
  final Uint8List instanceId;
  final String name;

  String get id => base64Url.encode(instanceId).replaceAll('=', '');

  static HostInfo parse(Uint8List v) {
    if (v.length < 17) throw FormatException('INFO is ${v.length} bytes');
    return HostInfo(v[0], Uint8List.sublistView(v, 1, 17), utf8.decode(v.sublist(17), allowMalformed: true));
  }
}

/// One BLE connection to a host: an ordered byte stream each way.
class HostLink implements Link {
  HostLink._(this.device, this.info, this._status, this._rx, this._chunkSize, this._incoming, this._txSub);

  /// How long a connect (plus MTU, discovery, INFO and subscribe) may take.
  static const connectTimeout = Duration(seconds: 5);

  final BleDevice device;
  final HostInfo info;
  final BleCharacteristic _status;
  final BleCharacteristic _rx;
  final int _chunkSize;
  final StreamController<Uint8List> _incoming;
  final StreamSubscription<Uint8List> _txSub;
  StreamSubscription<bool>? _connSub;
  Future<void> _writeQueue = Future.value();
  bool _dead = false;

  @override
  Stream<Uint8List> get incoming => _incoming.stream;

  /// Scans for BlueSteer hosts; a scan that cannot start is an error on the
  /// stream. Cancelling the subscription never waits on the plugin: its
  /// scan-stream cancel can hang after a connect, which stalled the whole
  /// connect path when this was an `async*` generator.
  static Stream<BleDevice> scan() {
    late StreamController<BleDevice> out;
    StreamSubscription<BleDevice>? inner;
    out = StreamController<BleDevice>(
      onListen: () async {
        try {
          await UniversalBle.startScan(scanFilter: ScanFilter(withServices: [bluesteerServiceUuid]));
        } catch (e, st) {
          out.addError(e, st);
          return;
        }
        if (out.isClosed) return;
        inner = UniversalBle.scanStream.listen((d) {
          debugPrint('[scan] ${d.deviceId} name=${d.name}');
          if (!out.isClosed) out.add(d);
        });
      },
      onCancel: () {
        inner?.cancel();
        out.close();
      },
    );
    return out.stream;
  }

  static const _namePrefix = 'BlueSteer ';

  /// The result carries the host's own local name (not a cached system name).
  static bool hasAdvertisedName(BleDevice d) => (d.name ?? '').startsWith(_namePrefix);

  /// The host name from the advertised local name `BlueSteer <name>`.
  static String advertisedName(BleDevice d) {
    final n = d.name ?? '';
    return n.startsWith(_namePrefix) ? n.substring(_namePrefix.length) : (n.isEmpty ? d.deviceId : n);
  }

  /// Connects, reads INFO, subscribes to TX. On any failure the device is
  /// disconnected again: the plugin's timeout is Dart-side only, so a connect
  /// it gave up on would otherwise keep going natively.
  static Future<HostLink> connect(BleDevice device, {Duration timeout = connectTimeout, Duration? pending}) async {
    try {
      return await _connect(device, pending: pending).timeout(timeout);
    } catch (_) {
      try {
        await UniversalBle.disconnect(device.deviceId);
      } catch (_) {}
      rethrow;
    }
  }

  /// [pending] keeps the connect request itself open that long (the plugin's
  /// default is 60 s); on iOS the system completes it when the peripheral is seen.
  static Future<HostLink> _connect(BleDevice device, {Duration? pending}) async {
    // iOS can keep a GATT link from a previous instance of the app (reinstall,
    // relaunch): connecting then succeeds at once, but the host still has the old
    // link and never sees a new subscribe, so the handshake goes nowhere. Start clean.
    try {
      if (await UniversalBle.getConnectionState(device.deviceId) == BleConnectionState.connected) {
        debugPrint('[link] ${device.deviceId} was still connected: dropping it first');
        await UniversalBle.disconnect(device.deviceId);
      }
    } catch (_) {}
    await device.connect(timeout: pending);
    var mtu = 23;
    try {
      mtu = await device.requestMtu(517);
    } catch (_) {}
    try {
      await UniversalBle.requestConnectionPriority(device.deviceId, BleConnectionPriority.highPerformance);
    } catch (_) {}
    final service = await device.getService(bluesteerServiceUuid);
    final info = HostInfo.parse(await service.getCharacteristic(_infoUuid).read());
    final status = service.getCharacteristic(_statusUuid);
    final tx = service.getCharacteristic(_txUuid);
    final rx = service.getCharacteristic(_rxUuid);
    final incoming = StreamController<Uint8List>.broadcast();
    final txSub = tx.onValueReceived.listen((v) {
      if (!incoming.isClosed) incoming.add(v);
    });
    // Android rejects writes above 512 bytes regardless of MTU (Phase 0 results).
    final link = HostLink._(device, info, status, rx, max(20, min(mtu - 3, 512)), incoming, txSub);
    link._connSub = device.connectionStream.listen((connected) {
      if (!connected) link._die();
    });
    try {
      await tx.notifications.subscribe();
    } catch (_) {
      link._die();
      rethrow;
    }
    return link;
  }

  /// STATUS bit 0 (SPEC.md §1.1): the host's pairing window is open.
  Future<bool> readPairingOpen() async {
    final v = await _status.read();
    return v.isNotEmpty && (v[0] & 1) == 1;
  }

  /// Writes bytes in order, chunked to what the link accepts. A failed write
  /// ends the link (the host is unreachable); later writes fail at once.
  @override
  Future<void> write(List<int> bytes) {
    final next = _writeQueue.then((_) => _writeChunks(bytes));
    _writeQueue = next.catchError((_) {});
    return next;
  }

  Future<void> _writeChunks(List<int> bytes) async {
    if (_dead) throw StateError('link closed');
    try {
      for (var i = 0; i < bytes.length; i += _chunkSize) {
        await _rx.write(bytes.sublist(i, min(i + _chunkSize, bytes.length)), withResponse: false);
      }
    } catch (_) {
      _die();
      rethrow;
    }
  }

  @override
  Future<void> close() async => _die();

  /// Ends the link once: stops listening, closes [incoming], disconnects.
  void _die() {
    if (_dead) return;
    _dead = true;
    _txSub.cancel();
    _connSub?.cancel();
    _incoming.close();
    device.disconnect().catchError((_) {});
  }
}
