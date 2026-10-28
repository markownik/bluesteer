import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:universal_ble/universal_ble.dart';

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

  static HostInfo parse(Uint8List v) =>
      HostInfo(v[0], Uint8List.sublistView(v, 1, 17), utf8.decode(v.sublist(17), allowMalformed: true));
}

/// One BLE connection to a host: an ordered byte stream each way.
class HostLink {
  HostLink._(this.device, this.info, this._status, this._rx, this._chunkSize, this._incoming);

  final BleDevice device;
  final HostInfo info;
  final BleCharacteristic _status;
  final BleCharacteristic _rx;
  final int _chunkSize;
  final StreamController<Uint8List> _incoming;
  Future<void> _writeQueue = Future.value();

  Stream<Uint8List> get incoming => _incoming.stream;
  Stream<bool> get connectionState => device.connectionStream;

  /// Scans for BlueSteer hosts. Stop with [UniversalBle.stopScan].
  static Stream<BleDevice> scan() {
    UniversalBle.startScan(scanFilter: ScanFilter(withServices: [bluesteerServiceUuid]));
    return UniversalBle.scanStream;
  }

  /// The host name from the advertised local name `BlueSteer <name>`.
  static String advertisedName(BleDevice d) {
    final n = d.name ?? '';
    return n.startsWith('BlueSteer ') ? n.substring(10) : (n.isEmpty ? d.deviceId : n);
  }

  /// Connects, reads INFO, subscribes to TX.
  static Future<HostLink> connect(BleDevice device) async {
    await device.connect();
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
    tx.onValueReceived.listen(incoming.add);
    await tx.notifications.subscribe();
    // Android rejects writes above 512 bytes regardless of MTU (Phase 0 results).
    return HostLink._(device, info, status, rx, max(20, min(mtu - 3, 512)), incoming);
  }

  /// STATUS bit 0 (SPEC.md §1.1): the host's pairing window is open.
  Future<bool> readPairingOpen() async {
    final v = await _status.read();
    return v.isNotEmpty && (v[0] & 1) == 1;
  }

  /// Writes bytes in order, chunked to what the link accepts.
  Future<void> write(List<int> bytes) {
    _writeQueue = _writeQueue.then((_) async {
      for (var i = 0; i < bytes.length; i += _chunkSize) {
        await _rx.write(bytes.sublist(i, min(i + _chunkSize, bytes.length)), withResponse: false);
      }
    });
    return _writeQueue;
  }

  Future<void> close() async {
    await _incoming.close();
    try {
      await device.disconnect();
    } catch (_) {}
  }
}
