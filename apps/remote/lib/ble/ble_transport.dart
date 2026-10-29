import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:universal_ble/universal_ble.dart';

import '../core/link.dart';
import 'host_link.dart';

/// Hosts over Bluetooth LE: scan for the service, connect to each advertiser
/// until one has the right INFO id.
class BleTransport implements Transport {
  bool _permissionsAsked = false;

  @override
  Stream<bool> get powered async* {
    yield await UniversalBle.getBluetoothAvailabilityState() == AvailabilityState.poweredOn;
    yield* UniversalBle.availabilityStream.map((s) => s == AvailabilityState.poweredOn);
  }

  /// Scans for up to [timeout]. The scan pauses while a candidate is being
  /// connected (GATT during a scan is unreliable on some Android stacks) and
  /// resumes if it was the wrong Mac.
  @override
  Future<Link> connect(String hostId, {required Duration timeout}) async {
    if (!_permissionsAsked) {
      await UniversalBle.requestPermissions();
      _permissionsAsked = true;
    }
    final found = Completer<Link>();
    final tried = <String>{};
    var busy = false;

    Future<void> tryDevice(BleDevice d) async {
      busy = true;
      try {
        await UniversalBle.stopScan();
        debugPrint('[link] connecting to ${d.deviceId}');
        final link = await HostLink.connect(d);
        debugPrint('[link] connected to ${link.info.name}');
        if (link.info.id == hostId && !found.isCompleted) {
          found.complete(link);
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

    final sub = HostLink.scan().listen((d) {
      if (busy || found.isCompleted || !tried.add(d.deviceId)) return;
      tryDevice(d);
    }, onError: (Object e) {
      if (!found.isCompleted) found.completeError(e);
    });
    try {
      final link = await found.future.timeout(timeout);
      debugPrint('[link] found $hostId');
      return link;
    } finally {
      await sub.cancel();
      try {
        await UniversalBle.stopScan();
      } catch (_) {}
    }
  }
}
