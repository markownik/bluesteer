import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bluesteer_protocol_dart/bluesteer_protocol_dart.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:xterm/xterm.dart';

import '../core/host_connection.dart';

/// A live terminal attached to one session on the host (SPEC.md §4).
/// Pops with `true` when the user asks for a new terminal after this one ended.
class TerminalPage extends StatefulWidget {
  const TerminalPage({super.key, required this.connection, required this.sessionId, required this.hostName, required this.cwd});
  final HostConnection connection;
  final String sessionId;
  final String hostName;
  /// Working directory when opened; follows SessionState afterwards.
  final String cwd;

  @override
  State<TerminalPage> createState() => _TerminalPageState();
}

class _TerminalPageState extends State<TerminalPage> with WidgetsBindingObserver {
  static const _inputChunk = 4000;
  /// After a reconnect the host may answer "no such session" for a moment
  /// while a surviving session re-attaches: ask once more after this long.
  static const _reattachGrace = Duration(seconds: 5);
  static const _reattachRetry = Duration(seconds: 2);

  final terminal = Terminal(maxLines: 5000);
  final _controller = TerminalController();
  StreamSubscription<Envelope>? _sub;
  StreamSubscription<void>? _reconnects;
  ByteConversionSink? _inflater; // per-subscription raw-deflate stream
  late final ByteConversionSink _utf8;
  Int64 _lastSeq = Int64.ZERO;
  String _status = 'connecting…';
  late String _cwd = widget.cwd;
  SessionStatus? _sessionStatus;
  int _cmdId = 1;
  int _subscribeCmdId = 0;
  bool _subscribed = false;
  bool _paused = false;
  /// A fresh snapshot was requested after a gap; further gaps wait for it.
  bool _resyncing = false;
  /// The session is gone for good: no more input.
  bool _ended = false;
  bool _applyingSnapshotSize = false;
  DateTime? _reconnectedAt;
  bool _retriedAfterReconnect = false;
  Timer? _resizeTimer;
  Timer? _retryTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _utf8 = const Utf8Decoder(allowMalformed: true)
        .startChunkedConversion(StringConversionSink.fromStringSink(_TerminalSink(terminal)));
    terminal.onOutput = (data) {
      if (_ended) return;
      // Keep each envelope small (SPEC.md §3): a long paste goes in several pieces.
      final bytes = utf8.encode(data);
      for (var i = 0; i < bytes.length; i += _inputChunk) {
        final end = i + _inputChunk < bytes.length ? i + _inputChunk : bytes.length;
        _send(Envelope()..termInput = (TermInput()..sessionId = widget.sessionId..data = bytes.sublist(i, end)));
      }
    };
    // The view sets the terminal size once it is laid out; subscribe with that
    // real size rather than the 80x24 default, so the host sizes the PTY to us.
    terminal.onResize = (w, h, _, _) {
      if (_applyingSnapshotSize) return; // the host's own size is not a request
      if (!_subscribed) {
        _subscribed = true;
        _subscribe();
      } else {
        // iOS animates the keyboard in, resizing the view a dozen times; send the settled size.
        _resizeTimer?.cancel();
        _resizeTimer = Timer(const Duration(milliseconds: 200), () {
          _send(Envelope()..resize = (Resize()..cmdId = Int64(_cmdId++)..sessionId = widget.sessionId..rows = h..cols = w));
        });
      }
    };
    _sub = widget.connection.envelopes.listen(_onEnvelope, onError: (_) {});
    widget.connection.state.addListener(_linkChanged);
    // After a reconnect the host has no subscriptions: ask for a fresh snapshot.
    _reconnects = widget.connection.reconnected.listen((_) {
      _reconnectedAt = DateTime.now();
      _retriedAfterReconnect = false;
      if (_subscribed && !_paused && !_ended) _subscribe();
    });
  }

  /// In the background the link stays up but nothing is drawn: stop the stream
  /// and ask for a fresh screen on return (no handshake needed).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_subscribed || _ended) return;
    if (state == AppLifecycleState.paused) {
      _paused = true;
      _send(Envelope()..unsubscribe = (Unsubscribe()..cmdId = Int64(_cmdId++)..sessionId = widget.sessionId));
    } else if (state == AppLifecycleState.resumed && _paused) {
      _paused = false;
      _subscribe();
    }
  }

  void _linkChanged() {
    if (!mounted) return;
    setState(() {
      if (widget.connection.state.value == LinkState.reconnecting) {
        _status = 'reconnecting…';
      } else if (widget.connection.state.value == LinkState.connected && _status == 'reconnecting…') {
        _status = 'connecting…';
      }
    });
  }

  void _subscribe() {
    _subscribeCmdId = _cmdId++;
    _resyncing = true;
    _send(Envelope()
      ..subscribe = (Subscribe()
        ..cmdId = Int64(_subscribeCmdId)
        ..sessionId = widget.sessionId
        ..rows = terminal.viewHeight
        ..cols = terminal.viewWidth
        ..scrollbackLines = 500));
  }

  Future<void> _send(Envelope e) async {
    try {
      await widget.connection.send(e);
    } catch (err) {
      if (mounted) setState(() => _status = 'send failed: $err');
    }
  }

  void _onEnvelope(Envelope e) {
    if (e.hasTermSnapshot() && e.termSnapshot.sessionId == widget.sessionId) {
      final snap = e.termSnapshot;
      _inflater?.close();
      _inflater = ZLibDecoder(raw: true).startChunkedConversion(_utf8);
      try {
        final vt = snap.compressed ? ZLibDecoder(raw: true).convert(snap.vt) : snap.vt;
        if (snap.rows != terminal.viewHeight || snap.cols != terminal.viewWidth) {
          // A session whose size we do not control (e.g. wrapped): follow it.
          _applyingSnapshotSize = true;
          terminal.resize(snap.cols, snap.rows);
          _applyingSnapshotSize = false;
        }
        _utf8.add(Uint8List.fromList(vt));
      } catch (_) {
        _subscribe(); // a damaged snapshot: ask again
        return;
      }
      _lastSeq = snap.seq;
      _resyncing = false;
      setState(() => _status = 'live');
    } else if (e.hasTermOutput() && e.termOutput.sessionId == widget.sessionId) {
      final out = e.termOutput;
      if (out.seq != _lastSeq + 1) {
        // Gap in the stream: ask for a fresh snapshot (once per gap).
        if (!_resyncing) _subscribe();
        return;
      }
      _lastSeq = out.seq;
      try {
        if (out.compressed) {
          _inflater?.add(out.data);
        } else {
          _utf8.add(Uint8List.fromList(out.data));
        }
      } catch (_) {
        if (!_resyncing) _subscribe();
      }
    } else if (e.hasAck() && !e.ack.ok && e.ack.cmdId == _subscribeCmdId) {
      final since = _reconnectedAt;
      if (since != null && !_retriedAfterReconnect && DateTime.now().difference(since) < _reattachGrace) {
        // The host just came back; its sessions may still be re-attaching.
        _retriedAfterReconnect = true;
        _retryTimer = Timer(_reattachRetry, () {
          if (mounted && !_ended) _subscribe();
        });
        return;
      }
      // The session is gone (e.g. it exited while we were away).
      setState(() {
        _ended = true;
        _status = 'ended: ${e.ack.error}';
      });
    } else if (e.hasSessionState() && e.sessionState.sessionId == widget.sessionId) {
      final st = e.sessionState;
      setState(() {
        _cwd = st.cwd;
        _sessionStatus = st.status;
        if (st.status == SessionStatus.SESSION_STATUS_EXITED) {
          _ended = true;
          _status = 'exited (${st.exitCode})';
        }
      });
    }
  }

  void _key(String seq) => terminal.onOutput?.call(seq);

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _resizeTimer?.cancel();
    _retryTimer?.cancel();
    _sub?.cancel();
    _reconnects?.cancel();
    widget.connection.state.removeListener(_linkChanged);
    if (!_ended) _send(Envelope()..unsubscribe = (Unsubscribe()..cmdId = Int64(_cmdId++)..sessionId = widget.sessionId));
    _inflater?.close();
    _controller.dispose();
    super.dispose();
  }

  Color get _statusColor {
    if (_status == 'live') {
      return switch (_sessionStatus) {
        SessionStatus.SESSION_STATUS_WAITING_PERMISSION => Colors.orange,
        SessionStatus.SESSION_STATUS_BUSY => Colors.lightBlue,
        _ => Colors.green,
      };
    }
    if (_status.startsWith('connecting') || _status.startsWith('reconnecting')) return Colors.amber;
    return Colors.red;
  }

  /// What Claude is doing, as learned from hooks on the host (SPEC.md §4.1).
  String? get _sessionLabel => switch (_sessionStatus) {
        SessionStatus.SESSION_STATUS_WAITING_PERMISSION => 'needs permission',
        SessionStatus.SESSION_STATUS_WAITING_INPUT => 'waiting for input',
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(children: [
          Tooltip(
            message: _status,
            child: Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(shape: BoxShape.circle, color: _statusColor),
            ),
          ),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.hostName, style: const TextStyle(fontSize: 14), overflow: TextOverflow.ellipsis),
              Text(_sessionLabel == null ? _cwd : '$_cwd  ·  $_sessionLabel',
                  style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  overflow: TextOverflow.ellipsis),
            ]),
          ),
        ]),
      ),
      body: Column(children: [
        if (_ended)
          MaterialBanner(
            content: Text(_status.startsWith('exited') ? 'This terminal has exited.' : 'This terminal is gone on the Mac.'),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('New terminal')),
            ],
          ),
        Expanded(
          child: TerminalView(
            terminal,
            controller: _controller,
            textStyle: const TerminalStyle(fontSize: 11),
            autofocus: !_ended,
            readOnly: _ended,
            // A plain keyboard: no predictions, autocorrect or auto-capitalisation.
            keyboardType: TextInputType.visiblePassword,
            // iOS soft keyboards send no key event for backspace; xterm detects
            // it from the text input instead.
            deleteDetection: true,
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView(scrollDirection: Axis.horizontal, children: [
            _KeyButton('Esc', _ended ? null : () => _key('\x1b')),
            _KeyButton('Tab', _ended ? null : () => _key('\t')),
            _KeyButton('⇧Tab', _ended ? null : () => _key('\x1b[Z')),
            _KeyButton('^C', _ended ? null : () => _key('\x03')),
            _KeyButton('^D', _ended ? null : () => _key('\x04')),
            _KeyButton('↑', _ended ? null : () => _key('\x1b[A')),
            _KeyButton('↓', _ended ? null : () => _key('\x1b[B')),
            _KeyButton('←', _ended ? null : () => _key('\x1b[D')),
            _KeyButton('→', _ended ? null : () => _key('\x1b[C')),
            _KeyButton('⏎', _ended ? null : () => _key('\r')),
          ]),
        ),
      ]),
    );
  }
}

class _KeyButton extends StatelessWidget {
  const _KeyButton(this.label, this.onTap);
  final String label;
  final VoidCallback? onTap;
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
