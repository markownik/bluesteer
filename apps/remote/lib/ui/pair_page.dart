import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:universal_ble/universal_ble.dart';

import '../ble/host_link.dart';
import '../core/host_session.dart';
import '../core/identity.dart';
import '../core/pairing_uri.dart';

/// Scans the host's QR code, finds that host over BLE and pairs with it.
class PairPage extends StatefulWidget {
  const PairPage({super.key, required this.identity, this.initialLink});
  final Identity identity;
  /// A `bluesteer://pair?...` link delivered to the app (deep link), skips the camera.
  final String? initialLink;

  @override
  State<PairPage> createState() => _PairPageState();
}

class _PairPageState extends State<PairPage> {
  PairingUri? _pairing;
  String _status = 'Scan the QR code shown by BlueSteer on your Mac';
  final _codeController = TextEditingController();
  StreamSubscription<BleDevice>? _scan;
  final _tried = <String>{};
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final link = widget.initialLink;
    if (link != null) WidgetsBinding.instance.addPostFrameCallback((_) => _onCode(link));
  }

  @override
  void dispose() {
    _scan?.cancel();
    UniversalBle.stopScan();
    _codeController.dispose();
    super.dispose();
  }

  void _onCode(String text) {
    if (_pairing != null) return;
    final parsed = PairingUri.tryParse(text);
    if (parsed == null) {
      setState(() => _status = 'That is not a BlueSteer pairing code');
      return;
    }
    setState(() {
      _pairing = parsed;
      _status = 'Looking for ${parsed.name} over Bluetooth…';
    });
    _findHost();
  }

  Future<void> _findHost() async {
    await UniversalBle.requestPermissions();
    _scan = HostLink.scan().listen((device) async {
      if (_busy || _tried.contains(device.deviceId)) return;
      _tried.add(device.deviceId);
      _busy = true;
      try {
        await _tryDevice(device);
      } finally {
        _busy = false;
      }
    });
  }

  Future<void> _tryDevice(BleDevice device) async {
    final pairing = _pairing!;
    setState(() => _status = 'Checking ${device.name ?? device.deviceId}…');
    HostLink? link;
    try {
      link = await HostLink.connect(device);
      if (link.info.id != _b64(pairing.hostId)) {
        await link.close();
        setState(() => _status = 'Not the right Mac, still looking…');
        return;
      }
      await UniversalBle.stopScan();
      setState(() => _status = 'Pairing with ${link!.info.name}…');
      final session = await HostSession.establish(link, identity: widget.identity.keyPair, pairingPsk: pairing.psk);
      await widget.identity.addHost(PairedHost(id: link.info.id, name: link.info.name, hostKey: session.hostKey));
      final rtt = await session.ping();
      await session.close();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Paired with ${link.info.name} (ping ${rtt.inMilliseconds} ms)')));
      Navigator.of(context).pop(true);
    } catch (e) {
      await link?.close();
      setState(() {
        _status = 'Pairing failed: $e';
        _pairing = null;
      });
    }
  }

  static String _b64(List<int> bytes) => base64Url.encode(bytes).replaceAll('=', '');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pair with a Mac')),
      body: Column(children: [
        if (_pairing == null)
          Expanded(
            child: MobileScanner(
              onDetect: (capture) {
                final value = capture.barcodes.firstOrNull?.rawValue;
                if (value != null) _onCode(value);
              },
            ),
          )
        else
          const Expanded(child: Center(child: CircularProgressIndicator())),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Text(_status, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            if (_pairing == null)
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _codeController,
                    autofocus: true,
                    decoration: const InputDecoration(labelText: 'or paste the pairing link'),
                    onSubmitted: _onCode,
                  ),
                ),
                IconButton(onPressed: () => _onCode(_codeController.text), icon: const Icon(Icons.send)),
              ]),
          ]),
        ),
      ]),
    );
  }
}
