import 'package:flutter/material.dart';

import '../core/host_session.dart';

/// Shows the 6-digit pairing code; the user confirms it matches the Mac's.
class PairCodePage extends StatefulWidget {
  const PairCodePage({super.key, required this.pending, required this.hostName});
  final PendingPairing pending;
  final String hostName;

  @override
  State<PairCodePage> createState() => _PairCodePageState();
}

class _PairCodePageState extends State<PairCodePage> {
  bool _waiting = false;
  String? _error;

  Future<void> _confirm() async {
    setState(() => _waiting = true);
    try {
      await widget.pending.confirm();
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _waiting = false;
          _error = 'The Mac did not accept the pairing: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final code = widget.pending.code;
    return Scaffold(
      appBar: AppBar(title: Text('Pair with ${widget.hostName}')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('${code.substring(0, 3)} ${code.substring(3)}',
              style: const TextStyle(fontSize: 56, fontWeight: FontWeight.w600, fontFeatures: [FontFeature.tabularFigures()])),
          const SizedBox(height: 24),
          Text('Does ${widget.hostName} show the same code? Confirm on both devices.', textAlign: TextAlign.center),
          const SizedBox(height: 32),
          if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 16), child: Text(_error!, textAlign: TextAlign.center)),
          if (_waiting)
            const Column(children: [CircularProgressIndicator(), SizedBox(height: 12), Text('Waiting for the Mac…')])
          else
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              OutlinedButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
              const SizedBox(width: 16),
              FilledButton(onPressed: _error == null ? _confirm : null, child: const Text('It matches')),
            ]),
        ]),
      ),
    );
  }
}
