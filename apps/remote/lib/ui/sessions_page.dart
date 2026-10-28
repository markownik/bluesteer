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
  List<String> _projects = const [];
  String? _lastCwd;
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
      } else if (e.hasProjects()) {
        setState(() => _projects = e.projects.recentCwds);
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
    final cwdController = TextEditingController(text: _lastCwd ?? _projects.firstOrNull ?? '');
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (ctx) => _NewSessionDialog(projects: _projects, cwdController: cwdController),
    );
    if (result == null || !mounted) return;
    final (preset, cwd) = result;
    _lastCwd = cwd;
    final size = MediaQuery.of(context).size;
    await widget.session.send(Envelope()
      ..newSession = (NewSession()
        ..cmdId = Int64(_cmdId++)
        ..preset = preset
        ..cwd = cwd
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
                    subtitle: Text('${s.cwd}  ·  ${s.status.name.replaceFirst('SESSION_STATUS_', '').toLowerCase()}'
                        '${s.source == SessionSource.SESSION_SOURCE_WRAPPED ? '  ·  your terminal' : ''}  ·  ${s.cols}×${s.rows}'),
                    onTap: () => _open(s),
                  ),
              ],
            ),
      floatingActionButton: FloatingActionButton(onPressed: _newSession, child: const Icon(Icons.add)),
    );
  }
}

class _NewSessionDialog extends StatefulWidget {
  const _NewSessionDialog({required this.projects, required this.cwdController});
  final List<String> projects;
  final TextEditingController cwdController;

  @override
  State<_NewSessionDialog> createState() => _NewSessionDialogState();
}

class _NewSessionDialogState extends State<_NewSessionDialog> {
  String _preset = 'claude';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New session'),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'claude', label: Text('Claude')),
              ButtonSegment(value: 'copilot', label: Text('Copilot')),
              ButtonSegment(value: 'shell', label: Text('Shell')),
            ],
            selected: {_preset},
            onSelectionChanged: (v) => setState(() => _preset = v.first),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: widget.cwdController,
            decoration: const InputDecoration(labelText: 'Project directory', isDense: true),
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 4, children: [
            for (final p in widget.projects)
              ActionChip(
                label: Text(p.split('/').last, style: const TextStyle(fontSize: 12)),
                tooltip: p,
                onPressed: () => widget.cwdController.text = p,
              ),
          ]),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.pop(context, (_preset, widget.cwdController.text.trim())),
          child: const Text('Start'),
        ),
      ],
    );
  }
}
