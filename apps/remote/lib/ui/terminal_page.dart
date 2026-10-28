import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bluesteer_protocol_dart/bluesteer_protocol_dart.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:xterm/xterm.dart';

import '../core/host_session.dart';

/// A live terminal attached to one session on the host (SPEC.md §4).
class TerminalPage extends StatefulWidget {
  const TerminalPage({super.key, required this.session, required this.sessionId, required this.title});
  final HostSession session;
  final String sessionId;
  final String title;

  @override
  State<TerminalPage> createState() => _TerminalPageState();
}

class _TerminalPageState extends State<TerminalPage> {
  final terminal = Terminal(maxLines: 5000);
  final _controller = TerminalController();
  StreamSubscription<Envelope>? _sub;
  ByteConversionSink? _inflater; // per-subscription raw-deflate stream
  late final ByteConversionSink _utf8;
  Int64 _lastSeq = Int64.ZERO;
  String _status = 'connecting…';
  int _cmdId = 1;
  bool _subscribed = false;

  @override
  void initState() {
    super.initState();
    _utf8 = const Utf8Decoder(allowMalformed: true)
        .startChunkedConversion(StringConversionSink.fromStringSink(_TerminalSink(terminal)));
    terminal.onOutput = (data) => _send(Envelope()..termInput = (TermInput()..sessionId = widget.sessionId..data = utf8.encode(data)));
    // The view sets the terminal size once it is laid out; subscribe with that
    // real size rather than the 80x24 default, so the host sizes the PTY to us.
    terminal.onResize = (w, h, _, _) {
      if (!_subscribed) {
        _subscribed = true;
        _subscribe();
      } else {
        _send(Envelope()..resize = (Resize()..cmdId = Int64(_cmdId++)..sessionId = widget.sessionId..rows = h..cols = w));
      }
    };
    _sub = widget.session.envelopes.listen(_onEnvelope, onError: (e) => setState(() => _status = 'error: $e'));
  }

  void _subscribe() {
    _send(Envelope()
      ..subscribe = (Subscribe()
        ..cmdId = Int64(_cmdId++)
        ..sessionId = widget.sessionId
        ..rows = terminal.viewHeight
        ..cols = terminal.viewWidth));
  }

  Future<void> _send(Envelope e) async {
    try {
      await widget.session.send(e);
    } catch (err) {
      if (mounted) setState(() => _status = 'send failed: $err');
    }
  }

  void _onEnvelope(Envelope e) {
    if (e.hasTermSnapshot() && e.termSnapshot.sessionId == widget.sessionId) {
      final snap = e.termSnapshot;
      _inflater?.close();
      _inflater = ZLibDecoder(raw: true).startChunkedConversion(_utf8);
      final vt = snap.compressed ? ZLibDecoder(raw: true).convert(snap.vt) : snap.vt;
      if (snap.rows != terminal.viewHeight || snap.cols != terminal.viewWidth) {
        // A session whose size we do not control (e.g. wrapped): follow it.
        terminal.resize(snap.cols, snap.rows);
      }
      _utf8.add(Uint8List.fromList(vt));
      _lastSeq = snap.seq;
      setState(() => _status = 'live');
    } else if (e.hasTermOutput() && e.termOutput.sessionId == widget.sessionId) {
      final out = e.termOutput;
      if (out.seq != _lastSeq + 1) {
        // Gap in the stream: ask for a fresh snapshot.
        _subscribe();
        return;
      }
      _lastSeq = out.seq;
      if (out.compressed) {
        _inflater?.add(out.data);
      } else {
        _utf8.add(Uint8List.fromList(out.data));
      }
    } else if (e.hasSessionState() && e.sessionState.sessionId == widget.sessionId) {
      final st = e.sessionState;
      if (st.status == SessionStatus.SESSION_STATUS_EXITED) {
        setState(() => _status = 'exited (${st.exitCode})');
      }
    }
  }

  void _key(String seq) => terminal.onOutput?.call(seq);

  @override
  void dispose() {
    _sub?.cancel();
    _send(Envelope()..unsubscribe = (Unsubscribe()..cmdId = Int64(_cmdId++)..sessionId = widget.sessionId));
    _inflater?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.title} · $_status', style: const TextStyle(fontSize: 14))),
      body: Column(children: [
        Expanded(
          child: TerminalView(
            terminal,
            controller: _controller,
            textStyle: const TerminalStyle(fontSize: 11),
            autofocus: true,
            // A plain keyboard: no predictions, autocorrect or auto-capitalisation.
            keyboardType: TextInputType.visiblePassword,
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView(scrollDirection: Axis.horizontal, children: [
            _KeyButton('Esc', () => _key('\x1b')),
            _KeyButton('Tab', () => _key('\t')),
            _KeyButton('⇧Tab', () => _key('\x1b[Z')),
            _KeyButton('^C', () => _key('\x03')),
            _KeyButton('^D', () => _key('\x04')),
            _KeyButton('↑', () => _key('\x1b[A')),
            _KeyButton('↓', () => _key('\x1b[B')),
            _KeyButton('←', () => _key('\x1b[D')),
            _KeyButton('→', () => _key('\x1b[C')),
            _KeyButton('⏎', () => _key('\r')),
          ]),
        ),
      ]),
    );
  }
}

class _KeyButton extends StatelessWidget {
  const _KeyButton(this.label, this.onTap);
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: OutlinedButton(onPressed: onTap, child: Text(label)),
      );
}

class _TerminalSink implements StringSink {
  _TerminalSink(this.terminal);
  final Terminal terminal;
  @override
  void write(Object? obj) => terminal.write(obj.toString());
  @override
  void writeAll(Iterable<dynamic> objects, [String separator = '']) => write(objects.join(separator));
  @override
  void writeCharCode(int charCode) => write(String.fromCharCode(charCode));
  @override
  void writeln([Object? obj = '']) => write('$obj\n');
}
