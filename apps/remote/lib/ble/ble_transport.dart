import 'dart:async';

import 'package:bluesteer_protocol_dart/bluesteer_protocol_dart.dart';
import 'package:flutter/foundation.dart';
import 'package:universal_ble/universal_ble.dart';

import '../core/host_session.dart';
import '../core/link.dart';
import 'host_link.dart';

/// Hosts over Bluetooth LE: scan for the service, connect to each advertiser
/// until one has the right INFO id.
class BleTransport implements Transport {
  bool _permissionsAsked = false;
  /// The device id each host was last reached at, for a direct connect while backgrounded.
  final _lastDeviceId = <String, String>{};

  @override
  Stream<bool> get powered async* {
    yield await UniversalBle.getBluetoothAvailabilityState() == AvailabilityState.poweredOn;
    yield* UniversalBle.availabilityStream.map((s) => s == AvailabilityState.poweredOn);
  }

  /// Scans for up to [timeout]. The scan pauses while a candidate is being
  /// connected (GATT during a scan is unreliable on some Android stacks) and
  /// resumes if it was the wrong Mac.
  @override
  Future<Link> connect(String hostId, {required Duration timeout, bool background = false}) async {
    if (!_permissionsAsked) {
      await UniversalBle.requestPermissions();
      _permissionsAsked = true;
    }
    final found = Completer<Link>();
    final tried = <String>{};
    var busy = false;

    // Backgrounded on iOS the scan may stay silent for minutes, but a connect to a
    // known peripheral is completed by the system the moment it advertises again:
    // keep one pending next to the scan, which still covers a rotated address.
    final direct = background ? _lastDeviceId[hostId] : null;
    var directPending = false;
    Future<void> tryDirect(String id) async {
      directPending = true;
      try {
        debugPrint('[link] direct connect to $id pending');
        final link = await HostLink.connect(BleDevice(deviceId: id, name: null), timeout: timeout, pending: timeout);
        if (link.info.id == hostId && link.info.protocolVersion == protocolVersion && !found.isCompleted) {
          debugPrint('[link] direct connect succeeded');
          found.complete(link);
          return;
        }
        await link.close();
      } catch (e) {
        debugPrint('[link] direct connect: $e');
      } finally {
        directPending = false;
      }
    }

    Future<void> tryDevice(BleDevice d) async {
      busy = true;
      try {
        await UniversalBle.stopScan();
        debugPrint('[link] connecting to ${d.deviceId}');
        final link = await HostLink.connect(d);
        debugPrint('[link] connected to ${link.info.name}');
        if (link.info.id == hostId && !found.isCompleted) {
          if (link.info.protocolVersion != protocolVersion) {
            await link.close();
            found.completeError(ProtocolMismatchException(link.info.protocolVersion));
            return;
          }
          found.complete(link);
          return;
        }
        if (found.isCompleted) {
          await link.close();
          return;
        }
        await link.close(); // the wrong Mac, or we gave up meanwhile
      } catch (e) {
        debugPrint('[link] ${HostLink.advertisedName(d)}: $e');
      } finally {
        busy = false;
      }
      if (found.isCompleted) return;
      try {
        await UniversalBle.startScan(scanFilter: ScanFilter(withServices: [bluesteerServiceUuid]));
      } catch (e) {
        if (!found.isCompleted) found.completeError(e);
      }
    }

    if (direct != null) tryDirect(direct);
    final sub = HostLink.scan().listen((d) {
      if (busy || found.isCompleted) return;
      if (directPending && d.deviceId == direct) {
        // The scan got there first: cancel the pending connect and take the normal path.
        debugPrint('[link] $direct seen by the scan, cancelling the direct connect');
        UniversalBle.disconnect(direct!).catchError((_) {});
        directPending = false;
      }
      if (!tried.add(d.deviceId)) return;
      tryDevice(d);
    }, onError: (Object e) {
      if (!found.isCompleted) found.completeError(e);
    });
    try {
      final link = await found.future.timeout(timeout);
      debugPrint('[link] found $hostId');
      if (link is HostLink) _lastDeviceId[hostId] = link.device.deviceId;
      if (direct != null && link is HostLink && link.device.deviceId != direct) {
        try {
          await UniversalBle.disconnect(direct); // the pending connect lost the race
        } catch (_) {}
      }
      return link;
    } finally {
      await sub.cancel();
      try {
        await UniversalBle.stopScan();
      } catch (_) {}
    }
  }
}
