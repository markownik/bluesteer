import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:universal_ble/universal_ble.dart';

import '../ble/host_link.dart';
import '../core/host_session.dart';
import '../core/identity.dart';
import 'pair_page.dart';
import 'sessions_page.dart';
import 'settings_page.dart';

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
    // Connect to each advertising Mac until one has the right INFO id.
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
      final link = await found.future.timeout(const Duration(seconds: 20));
      await sub.cancel();
      await UniversalBle.stopScan();
      setState(() => _status[host.id] = 'Authenticating…');
      _session = await HostSession.establish(link, identity: widget.identity, mode: PairingMode.paired, pinnedHostKey: host.hostKey);
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
      appBar: AppBar(title: const Text('BlueSteer'), actions: [
        IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SettingsPage(identity: widget.identity))),
        ),
      ]),
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
