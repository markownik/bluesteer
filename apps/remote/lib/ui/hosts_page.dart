import 'dart:async';
import 'dart:io';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

import '../core/host_connection.dart';
import '../core/identity.dart';
import '../demo/demo.dart';
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

class _HostsPageState extends State<HostsPage> with WidgetsBindingObserver {
  final _status = <String, String>{};
  HostConnection? _connection;
  StreamSubscription<Uri>? _links;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // bluesteer://pair?... links (QR alternative) open the pairing page directly.
    _links = AppLinks().uriLinkStream.listen((uri) => _pair(uri.toString()), onError: (_) {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _links?.cancel();
    _connection?.close();
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

  /// iOS delivers scan results slowly to a backgrounded app; the connection
  /// switches to a pending direct connect while we are away (Android's
  /// foreground service needs nothing).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _connection?.backgrounded = Platform.isIOS && state != AppLifecycleState.resumed;
  }

  Future<void> _connect(PairedHost host) async {
    if (widget.identity.requireUnlock && !await _unlock(host)) {
      if (mounted) setState(() => _status[host.id] = 'Locked: unlock to connect');
      return;
    }
    await _connection?.close();
    setState(() => _status[host.id] = 'Looking for ${host.name}…');
    final connection = HostConnection(identity: widget.identity, host: host, transport: demoMode ? DemoTransport(widget.identity) : null);
    _connection = connection;
    try {
      await connection.connect();
      // The Mac may have been renamed since pairing: keep its current name.
      final name = connection.hello?.hostName ?? '';
      if (name.isNotEmpty && name != host.name) {
        await widget.identity.addHost(PairedHost(id: host.id, name: name, hostKey: host.hostKey));
        if (mounted) setState(() {});
      }
      final rtt = await connection.ping();
      setState(() => _status[host.id] = 'Connected · ${connection.hello?.hostVersion ?? ''} · ping ${rtt.inMilliseconds} ms');
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => SessionsPage(connection: connection, hostName: name.isEmpty ? host.name : name)));
      if (mounted) setState(() => _status.remove(host.id));
    } catch (e) {
      if (mounted) setState(() => _status[host.id] = 'Failed: $e');
    } finally {
      await connection.close();
      if (_connection == connection) _connection = null;
    }
  }

  /// The biometric gate from Settings: the OS prompt (biometrics or passcode) must pass.
  Future<bool> _unlock(PairedHost host) async {
    try {
      return await LocalAuthentication().authenticate(localizedReason: 'Connect to ${host.name}');
    } catch (e) {
      debugPrint('[auth] $e');
      return false;
    }
  }

  /// Long press on a Mac: confirm before forgetting it (it must pair again).
  Future<void> _forget(PairedHost host) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Forget ${host.name}?'),
        content: const Text('This Mac will have to pair again before you can connect to it.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Forget')),
        ],
      ),
    );
    if (yes == true) {
      await widget.identity.removeHost(host.id);
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final hosts = widget.identity.hosts;
    return Scaffold(
      appBar: AppBar(title: const Text('BlueSteer'), actions: [
        IconButton(
          icon: const Icon(Icons.settings),
          tooltip: 'Settings',
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
                    onLongPress: () => _forget(h),
                  ),
              ],
            ),
      floatingActionButton: FloatingActionButton(onPressed: _pair, tooltip: 'Pair with a Mac', child: const Icon(Icons.add)),
    );
  }
}
