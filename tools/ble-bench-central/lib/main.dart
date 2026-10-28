// ble-bench-central: measures BLE throughput and round-trip time against
// ble-bench-peripheral running on a Mac. See tools/Sources/ble-bench-peripheral.
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:universal_ble/universal_ble.dart';

const serviceUuid = '7b5e5a6e-0001-4b1e-9c0e-5a2d2e1f0001';
const txUuid = '7b5e5a6e-0002-4b1e-9c0e-5a2d2e1f0001';
const rxUuid = '7b5e5a6e-0003-4b1e-9c0e-5a2d2e1f0001';

void main() => runApp(const MaterialApp(home: BenchPage()));

class BenchPage extends StatefulWidget {
  const BenchPage({super.key});
  @override
  State<BenchPage> createState() => _BenchPageState();
}

class _BenchPageState extends State<BenchPage> {
  final devices = <String, BleDevice>{};
  BleDevice? device;
  BleCharacteristic? tx, rx;
  int mtu = 23;
  final log = <String>[];

  // downlink stats
  int rxBytesWindow = 0, rxBytesTotal = 0, gaps = 0, lastSeq = -1;
  double rxKbps = 0;
  // uplink stats
  double txKbps = 0;
  // rtt
  final rtts = <int>[];
  Timer? ticker;

  @override
  void initState() {
    super.initState();
    ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        rxKbps = rxBytesWindow / 1024;
        rxBytesWindow = 0;
      });
      if (rxKbps > 0) say('rx ${rxKbps.toStringAsFixed(1)} KB/s  gaps $gaps  total ${(rxBytesTotal / 1024).toStringAsFixed(0)} KB');
    });
    start();
  }

  void say(String s) {
    debugPrint('[bench] $s');
    setState(() {
      log.insert(0, s);
      if (log.length > 200) log.removeLast();
    });
  }

  Future<void> start() async {
    await UniversalBle.requestPermissions();
    UniversalBle.scanStream.listen((d) {
      if (!devices.containsKey(d.deviceId)) {
        setState(() => devices[d.deviceId] = d);
        say('found ${d.name ?? '?'} ${d.deviceId} rssi ${d.rssi}');
        if (device == null && !connecting) autorun(d);
      }
    });
    await UniversalBle.startScan(scanFilter: ScanFilter(withServices: [serviceUuid]));
    say('scanning for BlueSteer bench…');
  }

  bool connecting = false;

  /// Connects to the first host found and runs the whole measurement sequence.
  Future<void> autorun(BleDevice d) async {
    connecting = true;
    try {
      await connect(d);
      await Future<void>.delayed(const Duration(seconds: 2));
      await pings();
      await floodDown(true);
      await Future<void>.delayed(const Duration(seconds: 15));
      await floodDown(false);
      say('downlink: ${(rxBytesTotal / 1024 / 15).toStringAsFixed(1)} KB/s average over 15 s, gaps $gaps');
      await Future<void>.delayed(const Duration(seconds: 2));
      await floodUp();
      await pings();
      say('AUTORUN DONE');
    } catch (e) {
      say('autorun failed: $e');
    }
  }

  Future<void> connect(BleDevice d) async {
    await UniversalBle.stopScan();
    say('connecting to ${d.name ?? d.deviceId}…');
    await d.connect();
    d.connectionStream.listen((c) => say(c ? 'connected' : 'disconnected'));
    try {
      mtu = await d.requestMtu(517);
    } catch (e) {
      say('requestMtu failed: $e');
    }
    say('mtu $mtu');
    try {
      await UniversalBle.requestConnectionPriority(d.deviceId, BleConnectionPriority.highPerformance);
      say('connection priority high requested');
    } catch (e) {
      say('requestConnectionPriority: $e');
    }
    final service = await d.getService(serviceUuid);
    tx = service.getCharacteristic(txUuid);
    rx = service.getCharacteristic(rxUuid);
    tx!.onValueReceived.listen(onNotify);
    await tx!.notifications.subscribe();
    setState(() => device = d);
    say('subscribed to TX');
  }

  void onNotify(Uint8List v) {
    if (v.isNotEmpty && v[0] == 0x01 && v.length >= 9) {
      final sent = ByteData.sublistView(v, 1, 9).getUint64(0);
      final rtt = DateTime.now().microsecondsSinceEpoch - sent;
      rtts.add(rtt);
      say('ping rtt ${(rtt / 1000).toStringAsFixed(1)} ms');
      return;
    }
    rxBytesWindow += v.length;
    rxBytesTotal += v.length;
    if (v.length >= 4) {
      final seq = ByteData.sublistView(v, 0, 4).getUint32(0);
      if (lastSeq >= 0 && seq != lastSeq + 1) gaps++;
      lastSeq = seq;
    }
  }

  Future<void> write(List<int> bytes) => rx!.write(bytes, withResponse: false);

  Future<void> floodDown(bool on) async {
    if (on) { rxBytesTotal = 0; gaps = 0; lastSeq = -1; }
    await write([on ? 0x02 : 0x03]);
    say(on ? 'downlink flood started' : 'downlink flood stopped');
  }

  Future<void> floodUp() async {
    for (final size in [20, 100, 244, mtu - 3]) {
      final chunk = Uint8List(size)..fillRange(0, size, 0x10);
      say('uplink 5 s with $size-byte writes…');
      final end = DateTime.now().add(const Duration(seconds: 5));
      var bytes = 0, writes = 0;
      final started = DateTime.now();
      try {
        while (DateTime.now().isBefore(end)) {
          await write(chunk);
          bytes += size; writes++;
        }
      } catch (e) {
        say('uplink $size failed after $writes writes: ${e.toString().split('\n').first}');
        continue;
      }
      final secs = DateTime.now().difference(started).inMilliseconds / 1000;
      setState(() => txKbps = bytes / 1024 / secs);
      say('uplink $size: ${txKbps.toStringAsFixed(1)} KB/s ($writes writes)');
    }
  }

  Future<void> pings() async {
    rtts.clear();
    for (var i = 0; i < 20; i++) {
      final b = ByteData(9)..setUint8(0, 0x01)..setUint64(1, DateTime.now().microsecondsSinceEpoch);
      await write(b.buffer.asUint8List());
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }
    if (rtts.isNotEmpty) {
      final s = [...rtts]..sort();
      say('rtt median ${(s[s.length ~/ 2] / 1000).toStringAsFixed(1)} ms  min ${(s.first / 1000).toStringAsFixed(1)}  max ${(s.last / 1000).toStringAsFixed(1)}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('BlueSteer BLE bench')),
      body: Column(children: [
        if (device == null)
          Expanded(
            child: ListView(
              children: devices.values
                  .map((d) => ListTile(title: Text(d.name ?? '(no name)'), subtitle: Text('${d.deviceId}  rssi ${d.rssi}'), onTap: () => connect(d)))
                  .toList(),
            ),
          )
        else ...[
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text('mtu $mtu   rx ${rxKbps.toStringAsFixed(1)} KB/s   gaps $gaps   tx ${txKbps.toStringAsFixed(1)} KB/s',
                style: Theme.of(context).textTheme.titleMedium),
          ),
          Wrap(spacing: 8, children: [
            FilledButton(onPressed: () => floodDown(true), child: const Text('Downlink start')),
            FilledButton(onPressed: () => floodDown(false), child: const Text('Downlink stop')),
            FilledButton(onPressed: floodUp, child: const Text('Uplink 10 s')),
            FilledButton(onPressed: pings, child: const Text('Ping ×20')),
          ]),
        ],
        const Divider(),
        Expanded(flex: 2, child: ListView(children: log.map((l) => Text(l, style: const TextStyle(fontFamily: 'monospace', fontSize: 12))).toList())),
      ]),
    );
  }
}
