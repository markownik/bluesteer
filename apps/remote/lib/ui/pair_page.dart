import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:universal_ble/universal_ble.dart';

import '../ble/host_link.dart';
import '../core/host_session.dart';
import '../core/identity.dart';
import '../core/pairing_uri.dart';
import 'pair_code_page.dart';

/// Pairs with a Mac: scan its QR code, or pick it from the nearby list and
/// compare a 6-digit code (SPEC.md §2.1).
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
  String _status = '';
  // One camera controller for the page's lifetime: re-creating the scanner
  // widget after a failed attempt restarts a camera that is still stopping.
  final _scanner = MobileScannerController(autoStart: false);
  StreamSubscription<BleDevice>? _scan;
  final _nearby = <String, BleDevice>{};
  /// Names read from INFO, by device id: phones only see a Mac's cached
  /// system name ("Mac") in scan results, so each nearby Mac is asked once.
  final _names = <String, String>{};
  final _resolving = <String>{};
  final _tried = <String>{};
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final link = widget.initialLink;
    if (link != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _onCode(link));
    } else {
      _scanner.start();
    }
    _startScan();
  }

  @override
  void dispose() {
    _scan?.cancel();
    UniversalBle.stopScan();
    _scanner.dispose();
    super.dispose();
  }

  Future<void> _startScan() async {
    await UniversalBle.requestPermissions();
    _scan?.cancel();
    _scan = HostLink.scan().listen((device) {
      // The first result for a Mac may carry only a cached system name ("Mac");
      // a later one with the advertised `BlueSteer <name>` replaces it.
      final known = _nearby[device.deviceId];
      if (known == null || (HostLink.hasAdvertisedName(device) && !HostLink.hasAdvertisedName(known))) {
        setState(() => _nearby[device.deviceId] = device);
      }
      if (_pairing != null) {
        _tryForQr(device);
      } else if (!HostLink.hasAdvertisedName(device)) {
        _resolveName(device);
      }
    }, onError: (Object e) {
      if (mounted) setState(() => _status = 'Bluetooth scan failed: $e');
    });
  }

  String _nameOf(BleDevice d) => _names[d.deviceId] ?? HostLink.advertisedName(d);

  /// Reads the Mac's name from INFO (no link is opened by a read), then scans on.
  Future<void> _resolveName(BleDevice device) async {
    if (_busy || _names.containsKey(device.deviceId) || !_resolving.add(device.deviceId)) return;
    _busy = true;
    try {
      await UniversalBle.stopScan();
      final link = await HostLink.connect(device);
      final name = link.info.name;
      await link.close();
      if (mounted) setState(() => _names[device.deviceId] = name);
    } catch (_) {
      _resolving.remove(device.deviceId); // a later result tries again
    } finally {
      _busy = false;
      if (mounted && _pairing == null) _startScan();
    }
  }

  // --- QR code / link -------------------------------------------------------

  void _onCode(String text) {
    if (_pairing != null || _busy) return;
    final parsed = PairingUri.tryParse(text);
    if (parsed == null) {
      setState(() => _status = 'That is not a BlueSteer pairing link');
      return;
    }
    setState(() {
      _pairing = parsed;
      _status = 'Looking for ${parsed.name} over Bluetooth…';
    });
    _scanner.stop();
    for (final d in _nearby.values) {
      _tryForQr(d);
    }
  }

  Future<void> _tryForQr(BleDevice device) async {
    if (_busy || _tried.contains(device.deviceId)) return;
    _tried.add(device.deviceId);
    _busy = true;
    try {
      await _pairWithPsk(device);
    } finally {
      _busy = false;
    }
  }

  Future<void> _pairWithPsk(BleDevice device) async {
    final pairing = _pairing!;
    setState(() => _status = 'Checking ${_nameOf(device)}…');
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
      final session = await HostSession.establish(link, identity: widget.identity, mode: PairingMode.psk, pairingPsk: pairing.psk);
      await _paired(link, session);
    } catch (e) {
      await link?.close();
      if (!mounted) return;
      setState(() {
        _status = 'Pairing failed: $e';
        _pairing = null;
      });
      _tried.clear();
      _scanner.start();
      _startScan();
    }
  }

  // --- Pairing by code -------------------------------------------------------

  Future<void> _pairByCode(BleDevice device) async {
    if (_busy) return;
    _busy = true;
    final name = _nameOf(device);
    setState(() => _status = 'Connecting to $name…');
    _scanner.stop();
    await UniversalBle.stopScan();
    HostLink? link;
    try {
      link = await HostLink.connect(device);
      if (!await link.readPairingOpen()) {
        await link.close();
        setState(() => _status = 'Open "Pair a remote…" in the BlueSteer menu on ${link!.info.name} first.');
        return;
      }
      setState(() => _status = 'Connecting securely…');
      final pending = await HostSession.pairByCode(link, identity: widget.identity);
      if (!mounted) return;
      final ok = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => PairCodePage(pending: pending, hostName: link!.info.name)),
      );
      if (ok == true) {
        await _paired(link, pending.session);
      } else {
        await link.close();
        setState(() => _status = '');
      }
    } catch (e) {
      await link?.close();
      if (mounted) setState(() => _status = 'Pairing failed: $e');
    } finally {
      _busy = false;
      if (mounted && _pairing == null) {
        _scanner.start();
        _startScan();
      }
    }
  }

  Future<void> _paired(HostLink link, HostSession session) async {
    await widget.identity.addHost(PairedHost(id: link.info.id, name: link.info.name, hostKey: session.hostKey));
    await session.close();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Paired with ${link.info.name}')));
    Navigator.of(context).pop(true);
  }

  Future<void> _pasteLink() async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pairing link'),
        content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(hintText: 'bluesteer://pair?…')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('Pair')),
        ],
      ),
    );
    if (text != null && text.isNotEmpty) _onCode(text);
  }

  static String _b64(List<int> bytes) => base64Url.encode(bytes).replaceAll('=', '');

  @override
  Widget build(BuildContext context) {
    final working = _pairing != null || _busy;
    return Scaffold(
      appBar: AppBar(title: const Text('Pair with a Mac')),
      body: Column(children: [
        Expanded(
          flex: 3,
          child: working
              ? const Center(child: CircularProgressIndicator())
              : Stack(alignment: Alignment.bottomCenter, children: [
                  MobileScanner(
                    controller: _scanner,
                    onDetect: (capture) {
                      final value = capture.barcodes.firstOrNull?.rawValue;
                      if (value != null) _onCode(value);
                    },
                  ),
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text('Scan the QR code from "Pair a remote…" on your Mac', style: TextStyle(shadows: [Shadow(blurRadius: 4)])),
                  ),
                ]),
        ),
        if (_status.isNotEmpty) Padding(padding: const EdgeInsets.all(12), child: Text(_status, textAlign: TextAlign.center)),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Align(alignment: Alignment.centerLeft, child: Text('Or pick a nearby Mac and compare a code', style: TextStyle(fontWeight: FontWeight.bold))),
        ),
        Expanded(
          flex: 2,
          child: _nearby.isEmpty
              ? const Center(child: Text('Looking for Macs running BlueSteer…'))
              : ListView(children: [
                  for (final d in _nearby.values)
                    ListTile(
                      leading: const Icon(Icons.laptop_mac),
                      title: Text(_nameOf(d)),
                      subtitle: Text(_names.containsKey(d.deviceId) || HostLink.hasAdvertisedName(d) ? 'Tap to pair by code' : 'Asking for its name…'),
                      enabled: !working,
                      onTap: () => _pairByCode(d),
                    ),
                ]),
        ),
        TextButton(onPressed: working ? null : _pasteLink, child: const Text('Paste a pairing link')),
        const SizedBox(height: 8),
      ]),
    );
  }
}
