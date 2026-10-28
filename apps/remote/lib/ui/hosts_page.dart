import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:universal_ble/universal_ble.dart';

import '../ble/host_link.dart';
import '../core/host_session.dart';
import '../core/identity.dart';
import 'pair_page.dart';
import 'sessions_page.dart';

/// Paired Macs. Tapping one connects, authenticates and shows the ping time.
class HostsPage extends StatefulWidget {
  const HostsPage({super.key, required this.identity});
  final Identity identity;

  @override
  State<HostsPage> createState() => _HostsPageState();
}

class _HostsPageState extends State<HostsPage> {
  final _status = <String, String>{};
  HostSession? _session;
  StreamSubscription<Uri>? _links;

  @override
  void initState() {
    super.initState();
    // bluesteer://pair?... links (QR alternative) open the pairing page directly.
    _links = AppLinks().uriLinkStream.listen((uri) => _pair(uri.toString()));
  }

  @override
  void dispose() {
    _links?.cancel();
    _session?.close();
    super.dispose();
  }

  bool _pairingOpen = false;

  Future<void> _pair([String? link]) async {
    // iOS can deliver one launch URL twice; two pairing pages would run two
    // handshakes over the same BLE link and corrupt each other.
    if (_pairingOpen) return;
    _pairingOpen = true;
    try {
      final paired = await Navigator.of(context)
          .push<bool>(MaterialPageRoute(builder: (_) => PairPage(identity: widget.identity, initialLink: link)));
      if (paired == true && mounted) setState(() {});
    } finally {
      _pairingOpen = false;
    }
  }

  Future<void> _connect(PairedHost host) async {
    await _session?.close();
    setState(() => _status[host.id] = 'Looking for ${host.name}…');
    await UniversalBle.requestPermissions();
    final found = Completer<BleDevice>();
    final tried = <String>{};
    final sub = HostLink.scan().listen((d) => !found.isCompleted && tried.add(d.deviceId) ? found.complete(d) : null);
    try {
      final device = await found.future.timeout(const Duration(seconds: 15));
      await sub.cancel();
      await UniversalBle.stopScan();
      setState(() => _status[host.id] = 'Connecting…');
      final link = await HostLink.connect(device);
      if (link.info.id != host.id) {
        await link.close();
        setState(() => _status[host.id] = 'Found a different Mac (${link.info.name})');
        return;
      }
      setState(() => _status[host.id] = 'Authenticating…');
      _session = await HostSession.establish(link, identity: widget.identity.keyPair, pinnedHostKey: host.hostKey);
      final rtt = await _session!.ping();
      setState(() => _status[host.id] = 'Connected · ${_session!.hello?.hostVersion ?? ''} · ping ${rtt.inMilliseconds} ms');
      _session!.link.connectionState.listen((c) {
        if (!c && mounted) setState(() => _status[host.id] = 'Disconnected');
      });
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => SessionsPage(session: _session!, hostName: host.name)));
    } catch (e) {
      await sub.cancel();
      await UniversalBle.stopScan();
      if (mounted) setState(() => _status[host.id] = 'Failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final hosts = widget.identity.hosts;
    return Scaffold(
      appBar: AppBar(title: const Text('BlueSteer')),
      body: hosts.isEmpty
          ? const Center(child: Text('No paired Macs yet.\nOpen BlueSteer on your Mac, choose "Pair a remote…", then tap +.', textAlign: TextAlign.center))
          : ListView(
              children: [
                for (final h in hosts)
                  ListTile(
                    leading: const Icon(Icons.laptop_mac),
                    title: Text(h.name),
                    subtitle: Text(_status[h.id] ?? 'Tap to connect'),
                    onTap: () => _connect(h),
                    onLongPress: () async {
                      await widget.identity.removeHost(h.id);
                      setState(() {});
                    },
                  ),
              ],
            ),
      floatingActionButton: FloatingActionButton(onPressed: _pair, child: const Icon(Icons.add)),
    );
  }
}
