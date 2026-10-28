import 'dart:async';

import 'package:bluesteer_protocol_dart/bluesteer_protocol_dart.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';

import '../core/host_session.dart';
import 'terminal_page.dart';

/// Sessions on one connected host; start new ones or open a terminal to one.
class SessionsPage extends StatefulWidget {
  const SessionsPage({super.key, required this.session, required this.hostName});
  final HostSession session;
  final String hostName;

  @override
  State<SessionsPage> createState() => _SessionsPageState();
}

class _SessionsPageState extends State<SessionsPage> {
  final _sessions = <String, SessionState>{};
  StreamSubscription<Envelope>? _sub;
  int _cmdId = 1000;

  @override
  void initState() {
    super.initState();
    _sub = widget.session.envelopes.listen((e) {
      if (e.hasSessionList()) {
        setState(() {
          _sessions.clear();
          for (final s in e.sessionList.sessions) {
            _sessions[s.sessionId] = s;
          }
        });
      } else if (e.hasSessionState()) {
        setState(() => _sessions[e.sessionState.sessionId] = e.sessionState);
      }
    });
    widget.session.send(Envelope()..listSessions = (ListSessions()..cmdId = Int64(_cmdId++)));
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _newSession() async {
    final preset = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('New session'),
        children: [
          for (final p in const [('claude', 'Claude Code'), ('copilot', 'Copilot CLI'), ('shell', 'Shell')])
            SimpleDialogOption(onPressed: () => Navigator.pop(ctx, p.$1), child: Text(p.$2)),
        ],
      ),
    );
    if (preset == null || !mounted) return;
    final size = MediaQuery.of(context).size;
    await widget.session.send(Envelope()
      ..newSession = (NewSession()
        ..cmdId = Int64(_cmdId++)
        ..preset = preset
        ..rows = (size.height / 22).floor().clamp(10, 60)
        ..cols = (size.width / 7).floor().clamp(40, 200)));
  }

  void _open(SessionState s) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => TerminalPage(session: widget.session, sessionId: s.sessionId, title: s.title.isEmpty ? s.command : s.title),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final list = _sessions.values.toList();
    return Scaffold(
      appBar: AppBar(title: Text(widget.hostName)),
      body: list.isEmpty
          ? const Center(child: Text('No sessions. Tap + to start one.'))
          : ListView(
              children: [
                for (final s in list)
                  ListTile(
                    leading: Icon(s.status == SessionStatus.SESSION_STATUS_EXITED ? Icons.stop_circle_outlined : Icons.terminal),
                    title: Text(s.title.isEmpty ? s.command : s.title),
                    subtitle: Text('${s.cwd}  ·  ${s.status.name.replaceFirst('SESSION_STATUS_', '').toLowerCase()}  ·  ${s.cols}×${s.rows}'),
                    onTap: () => _open(s),
                  ),
              ],
            ),
      floatingActionButton: FloatingActionButton(onPressed: _newSession, child: const Icon(Icons.add)),
    );
  }
}
