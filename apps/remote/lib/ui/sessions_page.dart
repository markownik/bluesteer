import 'dart:async';

import 'package:bluesteer_protocol_dart/bluesteer_protocol_dart.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';

import '../core/host_connection.dart';
import 'terminal_page.dart';

/// Terminals running on one connected Mac; open one or start a new shell.
class SessionsPage extends StatefulWidget {
  const SessionsPage({super.key, required this.connection, required this.hostName});
  final HostConnection connection;
  final String hostName;

  @override
  State<SessionsPage> createState() => _SessionsPageState();
}

class _SessionsPageState extends State<SessionsPage> {
  final _sessions = <String, SessionState>{};
  final _pendingAcks = <Int64, Completer<Ack>>{};
  StreamSubscription<Envelope>? _sub;
  StreamSubscription<void>? _reconnects;
  int _cmdId = 1000;
  bool _listed = false;
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    _sub = widget.connection.envelopes.listen((e) {
      if (e.hasSessionList()) {
        setState(() {
          _sessions.clear();
          for (final s in e.sessionList.sessions) {
            if (s.status != SessionStatus.SESSION_STATUS_EXITED) _sessions[s.sessionId] = s;
          }
        });
        // First connect with nothing running: open a terminal straight away.
        if (!_listed && _sessions.isEmpty) _newTerminal();
        _listed = true;
      } else if (e.hasSessionState()) {
        final s = e.sessionState;
        setState(() {
          if (s.status == SessionStatus.SESSION_STATUS_EXITED) {
            _sessions.remove(s.sessionId);
          } else {
            _sessions[s.sessionId] = s;
          }
        });
      } else if (e.hasAck()) {
        _pendingAcks.remove(e.ack.cmdId)?.complete(e.ack);
      }
    });
    _reconnects = widget.connection.reconnected.listen((_) => _list());
    _list();
  }

  void _list() => widget.connection.send(Envelope()..listSessions = (ListSessions()..cmdId = Int64(_cmdId++))).ignore();

  @override
  void dispose() {
    _sub?.cancel();
    _reconnects?.cancel();
    super.dispose();
  }

  Future<void> _newTerminal() async {
    if (_starting) return;
    setState(() => _starting = true);
    final cmdId = Int64(_cmdId++);
    final ack = Completer<Ack>();
    _pendingAcks[cmdId] = ack;
    final size = MediaQuery.of(context).size;
    try {
      await widget.connection.send(Envelope()
        ..newSession = (NewSession()
          ..cmdId = cmdId
          ..preset = 'shell'
          ..rows = (size.height / 22).floor().clamp(10, 60)
          ..cols = (size.width / 7).floor().clamp(40, 200)));
      final result = await ack.future.timeout(const Duration(seconds: 10));
      if (!mounted) return;
      if (!result.ok) throw result.error;
      _open(result.sessionId, _sessions[result.sessionId]?.cwd ?? '');
    } catch (e) {
      _pendingAcks.remove(cmdId);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not start a terminal: $e')));
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _open(String sessionId, String cwd) async {
    final wantsNew = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => TerminalPage(connection: widget.connection, sessionId: sessionId, hostName: widget.hostName, cwd: cwd),
    ));
    if (wantsNew == true && mounted) _newTerminal();
  }

  static String _commandOf(SessionState s) => s.title.isNotEmpty ? s.title : s.command.split('/').last;

  @override
  Widget build(BuildContext context) {
    final list = _sessions.values.toList();
    return Scaffold(
      appBar: AppBar(title: Text(widget.hostName)),
      body: Column(children: [
        ValueListenableBuilder<LinkState>(
          valueListenable: widget.connection.state,
          builder: (_, state, _) => switch (state) {
            LinkState.reconnecting => MaterialBanner(
                content: Semantics(liveRegion: true, child: Text('Reconnecting to ${widget.hostName}…')),
                actions: const [SizedBox.shrink()]),
            LinkState.dismissed => MaterialBanner(
                content: Semantics(liveRegion: true, child: Text(widget.connection.error ?? 'Disconnected by ${widget.hostName}')),
                actions: [TextButton(onPressed: widget.connection.reconnect, child: const Text('Reconnect'))]),
            _ => const SizedBox.shrink(),
          },
        ),
        Expanded(child: list.isEmpty
          ? Center(child: Text(_starting ? 'Starting a terminal…' : 'No terminals running.'))
          : ListView(
              children: [
                for (final s in list)
                  ListTile(
                    leading: const Icon(Icons.terminal),
                    title: Text(s.cwd),
                    subtitle: Text(s.source == SessionSource.SESSION_SOURCE_WRAPPED ? '${_commandOf(s)}  ·  your terminal' : _commandOf(s)),
                    onTap: () => _open(s.sessionId, s.cwd),
                  ),
              ],
            )),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _starting ? null : _newTerminal,
        icon: const Icon(Icons.add),
        label: const Text('New terminal'),
      ),
    );
  }
}
